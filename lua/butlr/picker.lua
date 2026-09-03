local state = require("butlr.state")
local actions = require("butlr.actions")

local M = {}

local icons = {
  unassigned = "󰜺",
  branch = "󰊢",
  commit = "󰜘",
  commit_new = "󰜘",
  absorb = "󰃀",
  uncommit = "󰜺",
  unapply = "󰜺",
  discard = "󰩹",
  stack = "󰜏",
}

local function snacks_pick(items, opts)
  local Snacks = require("snacks")
  Snacks.picker({
    title = opts.title,
    items = items,
    format = function(item)
      local parts = {}
      local indent = item.indent or ""
      table.insert(parts, { indent .. (item.icon or " ") .. " ", item.icon_hl or "Comment" })
      table.insert(parts, { item.cli_id and (item.cli_id .. " ") or "", "ButlrHunkId" })
      table.insert(parts, { item.text, item.text_hl or "Normal" })
      if item.desc and item.desc ~= "" then
        table.insert(parts, { "  " .. item.desc, "Comment" })
      end
      return parts
    end,
    confirm = function(picker, item)
      picker:close()
      if opts.on_select then
        opts.on_select(item)
      end
    end,
  })
end

local function branch_prefix(branch)
  return branch.depth > 1 and "└" .. string.rep("──", branch.depth - 1) .. " " or ""
end

--- Route a source change onto the chosen target using the 0.22 command set.
--- `but rub`/`but stage` were retired; assignment is now amend/commit/squash/move.
local function dispatch(source, item)
  local committed = source.commit_id ~= nil

  if item.kind == "uncommitted" then
    if not committed then
      vim.notify("[butlr] source is already uncommitted", vim.log.levels.INFO)
      return
    end
    actions.uncommit(source.id)
  elseif item.kind == "commit" then
    if committed then
      actions.squash({ source.id }, item.target_id)
    else
      actions.amend(item.target_id, { source.id })
    end
  elseif item.kind == "branch" then
    if committed then
      actions.move_to_branch({ source.id }, item.target_id)
    elseif item.has_commits then
      actions.amend(item.target_id, { source.id })
    else
      vim.ui.input({ prompt = "Commit message for " .. item.target_id .. ": " }, function(msg)
        if msg and msg ~= "" then
          actions.commit(item.target_id, msg, { source.id })
        end
      end)
    end
  end
end

function M.assign()
  local hunk, file_data = state.get_hunk_at_cursor()
  local source
  local source_label

  if hunk then
    source = { id = hunk.id, commit_id = hunk.commit_id }
    source_label = ("%s (%s)"):format(hunk.id, file_data.path)
  elseif file_data then
    source = { id = file_data.id, commit_id = file_data.commit_id }
    source_label = ("%s (%s)"):format(file_data.id, file_data.path)
  else
    vim.notify("[butlr] no hunk or file under cursor", vim.log.levels.INFO)
    return
  end

  local items = {}

  if source.commit_id then
    table.insert(items, {
      text = "uncommitted",
      icon = icons.uncommit,
      icon_hl = "DiagnosticWarn",
      cli_id = "zz",
      desc = "uncommit back into the working tree",
      kind = "uncommitted",
    })
  end

  for _, branch in ipairs(state.data.branches) do
    local has_commits = #branch.commits > 0
    local desc_parts = { has_commits and "amend into branch tip" or "commit onto branch" }
    if branch.stack_name then
      table.insert(desc_parts, "stack: " .. branch.stack_name)
    end

    table.insert(items, {
      text = branch.name,
      icon = icons.branch,
      icon_hl = "Function",
      cli_id = branch.cli_id,
      indent = branch_prefix(branch),
      desc = table.concat(desc_parts, " · "),
      kind = "branch",
      -- mutations must use full branch names; short IDs are snapshot-local
      target_id = branch.name,
      has_commits = has_commits,
    })

    local commit_pad = branch.depth > 1
      and " " .. string.rep("  ", branch.depth - 1) .. " " or " "
    for _, commit in ipairs(branch.commits) do
      local msg = (commit.message or ""):gsub("\n.*", "")
      if #msg > 50 then
        msg = msg:sub(1, 47) .. "..."
      end
      local commit_id = commit.cliId or commit.commitId:sub(1, 7)
      table.insert(items, {
        text = msg,
        icon = icons.commit,
        icon_hl = "Number",
        cli_id = commit_id,
        indent = commit_pad,
        desc = source.commit_id and "squash into this commit" or "amend into this commit",
        kind = "commit",
        target_id = commit_id,
      })
    end
  end

  snacks_pick(items, {
    title = "assign " .. source_label .. " → ",
    on_select = function(item)
      if item and item.kind then
        dispatch(source, item)
      end
    end,
  })
end

-- `but rub` was retired upstream; keep the old entry point for existing keymaps.
M.rub = M.assign

function M.branches()
  local items = {}

  if #state.data.unassigned > 0 then
    table.insert(items, {
      text = "uncommitted",
      icon = icons.unassigned,
      icon_hl = "DiagnosticWarn",
      cli_id = "zz",
      desc = #state.data.unassigned .. " uncommitted files",
      branch = { cli_id = "zz", name = "uncommitted" },
    })
  end

  for _, branch in ipairs(state.data.branches) do
    local commit_count = #branch.commits
    local change_count = #branch.changes
    local desc_parts = {}
    if commit_count > 0 then
      table.insert(desc_parts, commit_count .. " commit" .. (commit_count > 1 and "s" or ""))
    else
      table.insert(desc_parts, "no commits")
    end
    if change_count > 0 then
      table.insert(desc_parts, change_count .. " assigned")
    end
    if branch.stack_name then
      table.insert(desc_parts, "stack: " .. branch.stack_name)
    end

    table.insert(items, {
      text = branch.name,
      icon = icons.branch,
      icon_hl = "Function",
      cli_id = branch.cli_id,
      indent = branch_prefix(branch),
      desc = table.concat(desc_parts, " · "),
      branch = branch,
    })
  end

  snacks_pick(items, {
    title = "Branches",
    on_select = function(item)
      if not item or not item.branch then
        return
      end
      M._branch_actions(item.branch)
    end,
  })
end

function M._branch_actions(branch)
  local is_uncommitted = branch.cli_id == "zz"
  local items = {
    { text = "Absorb uncommitted changes", icon = icons.absorb, icon_hl = "DiagnosticHint", action = "absorb" },
  }

  if is_uncommitted then
    table.insert(items, { text = "Discard all", icon = icons.discard, icon_hl = "DiagnosticError", action = "discard" })
  else
    table.insert(items, {
      text = "Commit all uncommitted here",
      icon = icons.commit_new,
      icon_hl = "Number",
      action = "commit",
    })
    table.insert(items, { text = "Unapply", icon = icons.unapply, icon_hl = "DiagnosticWarn", action = "unapply" })
  end

  snacks_pick(items, {
    title = branch.name,
    on_select = function(item)
      if not item then
        return
      end
      if item.action == "absorb" then
        actions.absorb()
      elseif item.action == "discard" then
        actions.discard("zz")
      elseif item.action == "commit" then
        vim.ui.input({ prompt = "Commit message for " .. branch.name .. ": " }, function(msg)
          if msg and msg ~= "" then
            actions.commit(branch.name, msg, {})
          end
        end)
      elseif item.action == "unapply" then
        actions.unapply(branch.name)
      end
    end,
  })
end

return M
