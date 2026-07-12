local cli = require("butlr.cli")
local config = require("butlr.config")

local M = {}

---@class butlr.HunkInfo
---@field id string
---@field new_start number
---@field new_lines number
---@field old_start number
---@field old_lines number

---@class butlr.FileChange
---@field id string
---@field path string
---@field status string
---@field hunks butlr.HunkInfo[]
---@field branch_name? string
---@field stack_name? string

---@class butlr.Branch
---@field name string
---@field cli_id string
---@field is_applied boolean
---@field stack_name? string
---@field depth number
---@field commits table[]
---@field changes table[]

---@class butlr.State
---@field unassigned table[]
---@field branches butlr.Branch[]
---@field hunks table<string, butlr.FileChange>
---@field merge_base table?
---@field upstream table?
---@field active_mark? string
---@field conflicted boolean

M.data = {
  unassigned = {},
  branches = {},
  hunks = {},
  merge_base = nil,
  upstream = nil,
  active_mark = nil,
  conflicted = false,
}

local refresh_timer = nil

local function parse_status(status)
  local state = {
    unassigned = status.unassignedChanges or {},
    branches = {},
    staging_areas = {},
    merge_base = status.mergeBase,
    upstream = status.upstreamState,
    conflicted = false,
  }

  for _, stack in ipairs(status.stacks or {}) do
    local stack_cli_id = stack.cliId or ""
    local root_branch_name = ""
    if stack.branches and #stack.branches > 0 then
      root_branch_name = stack.branches[#stack.branches].name or ""
    end

    if stack.assignedChanges and #stack.assignedChanges > 0 and stack_cli_id ~= "" then
      table.insert(state.staging_areas, {
        cli_id = stack_cli_id,
        branch_name = root_branch_name,
      })
    end

    local branches = stack.branches or {}
    local num_branches = #branches
    for i = num_branches, 1, -1 do
      local branch = branches[i]
      local depth = num_branches - i + 1
      local b = {
        name = branch.name or "",
        cli_id = branch.cliId or "",
        is_applied = true,
        stack_name = stack.name,
        depth = depth,
        commits = branch.commits or {},
        changes = stack.assignedChanges or {},
      }
      for _, commit in ipairs(b.commits) do
        if commit.conflicted then
          state.conflicted = true
        end
      end
      table.insert(state.branches, b)
    end
  end

  return state
end

local function parse_changed_lines(diff_text, new_start)
  local added = {}
  local removed_at = {}
  local new_line = new_start
  for line in diff_text:gmatch("[^\n]+") do
    if line:sub(1, 2) == "@@" then
      -- skip the hunk header
    elseif line:sub(1, 1) == "+" then
      table.insert(added, new_line)
      new_line = new_line + 1
    elseif line:sub(1, 1) == "-" then
      table.insert(removed_at, new_line)
    else
      new_line = new_line + 1
    end
  end
  return added, removed_at
end

local function parse_diff(diff_data, fallback_id)
  local hunks = {}
  for _, change in ipairs(diff_data.changes or {}) do
    if change.diff and change.diff.hunks then
      local hunk_id = change.id or fallback_id
      local file_hunks = {}
      for _, h in ipairs(change.diff.hunks) do
        local added, removed_at = parse_changed_lines(h.diff or "", h.newStart)
        table.insert(file_hunks, {
          id = hunk_id,
          new_start = h.newStart,
          new_lines = h.newLines,
          old_start = h.oldStart,
          old_lines = h.oldLines,
          added_lines = added,
          removed_at = removed_at,
        })
      end
      if hunks[change.path] then
        vim.list_extend(hunks[change.path].hunks, file_hunks)
      else
        hunks[change.path] = {
          id = hunk_id,
          path = change.path,
          status = change.status,
          hunks = file_hunks,
        }
      end
    end
  end
  return hunks
end

local function merge_hunks(target, source, branch_name)
  for path, file_change in pairs(source) do
    for _, hunk in ipairs(file_change.hunks) do
      hunk.branch_name = branch_name
    end
    if target[path] then
      vim.list_extend(target[path].hunks, file_change.hunks)
    else
      target[path] = file_change
    end
  end
end

local function emit()
  vim.api.nvim_exec_autocmds("User", { pattern = "ButlrStateChanged" })
end

function M.refresh(callback)
  if refresh_timer then
    refresh_timer:stop()
  end

  refresh_timer = vim.defer_fn(function()
    refresh_timer = nil
    M._do_refresh(callback)
  end, config.options.refresh_debounce_ms)
end

function M.refresh_now(callback)
  M._do_refresh(callback)
end

function M._do_refresh(callback)
  -- Phase 1: get status
  cli.run({ "status" }, {
    on_success = function(status_data)
      local parsed = parse_status(status_data)

      local staging_areas = parsed.staging_areas or {}

      -- Collect commits from unintegrated branches
      local commit_sources = {}
      for _, branch in ipairs(parsed.branches) do
        for _, commit in ipairs(branch.commits) do
          local cli_id = commit.cliId or commit.commitId:sub(1, 7)
          table.insert(commit_sources, {
            cli_id = cli_id,
            branch_name = branch.name,
          })
        end
      end

      -- Phase 2: fetch unassigned + staging areas + committed diffs in parallel
      local total = 1 + #staging_areas + #commit_sources
      local pending = total
      local all_hunks = {}

      local function try_finish()
        pending = pending - 1
        if pending > 0 then
          return
        end

        parsed.hunks = all_hunks
        M.data = parsed

        if parsed.conflicted and config.options.notify_conflicts then
          vim.notify("[butlr] conflicted commits detected", vim.log.levels.WARN)
        end

        emit()

        if callback then
          callback(M.data)
        end
      end

      -- Unassigned diff
      cli.run({ "diff" }, {
        on_success = function(data)
          local hunks = parse_diff(data)
          merge_hunks(all_hunks, hunks, nil)
          try_finish()
        end,
        on_error = function()
          try_finish()
        end,
      })

      -- Staged diffs per staging area
      for _, sa in ipairs(staging_areas) do
        cli.run({ "diff", sa.cli_id }, {
          on_success = function(data)
            local hunks = parse_diff(data)
            merge_hunks(all_hunks, hunks, sa.branch_name)
            try_finish()
          end,
          on_error = function()
            try_finish()
          end,
        })
      end

      -- Committed diffs per commit
      for _, cs in ipairs(commit_sources) do
        cli.run({ "diff", cs.cli_id }, {
          on_success = function(data)
            local hunks = parse_diff(data, cs.cli_id)
            merge_hunks(all_hunks, hunks, cs.branch_name)
            try_finish()
          end,
          on_error = function()
            try_finish()
          end,
        })
      end
    end,
    on_error = function()
      if callback then
        callback(M.data)
      end
    end,
  })
end

function M.update_from_status_after(status_data)
  if not status_data then
    return
  end
  -- Full refresh since staging areas may have changed
  M._do_refresh()
end

function M.get_hunk_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local rel = vim.fn.fnamemodify(file, ":.")
  local file_data = M.data.hunks[rel]
  if not file_data then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  for _, hunk in ipairs(file_data.hunks) do
    if cursor_line >= hunk.new_start and cursor_line < hunk.new_start + math.max(hunk.new_lines, 1) then
      return hunk, file_data
    end
  end
  return nil, file_data
end

return M
