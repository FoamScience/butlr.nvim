local state = require("butlr.state")
local actions = require("butlr.actions")

local M = {}

local icons = {
  unassigned = "󰜺",
  branch = "󰊢",
  commit = "󰜘",
  mark = "󰃀",
  unmark = "󰃃",
  unapply = "󰜺",
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

function M.rub()
  local hunk, file_data = state.get_hunk_at_cursor()
  local source_id
  local source_label

  if hunk then
    source_id = hunk.id
    source_label = ("%s (%s)"):format(hunk.id, file_data.path)
  elseif file_data then
    source_id = file_data.id
    source_label = ("%s (%s)"):format(file_data.id, file_data.path)
  else
    vim.notify("[butlr] no hunk or file under cursor", vim.log.levels.INFO)
    return
  end

  local items = {}

  table.insert(items, {
    text = "unassigned",
    icon = icons.unassigned,
    icon_hl = "DiagnosticWarn",
    cli_id = "zz",
    desc = "move to unassigned pool",
    target_id = "zz",
  })

  for _, branch in ipairs(state.data.branches) do
    local prefix = branch.depth > 1
      and "└" .. string.rep("──", branch.depth - 1) .. " " or ""
    local desc_parts = {}
    table.insert(desc_parts, "stage to branch")
    if branch.stack_name then
      table.insert(desc_parts, "stack: " .. branch.stack_name)
    end
    local change_count = #branch.changes
    if change_count > 0 then
      table.insert(desc_parts, change_count .. " staged")
    end

    table.insert(items, {
      text = branch.name,
      icon = icons.branch,
      icon_hl = "Function",
      cli_id = branch.cli_id,
      indent = prefix,
      desc = table.concat(desc_parts, " · "),
      target_id = branch.cli_id,
    })

    local commit_pad = branch.depth > 1
      and " " .. string.rep("  ", branch.depth - 1) .. " " or " "
    for _, commit in ipairs(branch.commits) do
      local msg = (commit.message or ""):gsub("\n.*", "")
      if #msg > 50 then
        msg = msg:sub(1, 47) .. "..."
      end
      table.insert(items, {
        text = msg,
        icon = icons.commit,
        icon_hl = "Number",
        cli_id = commit.cliId or commit.commitId:sub(1, 7),
        indent = commit_pad,
        desc = "amend into this commit",
        target_id = commit.cliId or commit.commitId:sub(1, 7),
      })
    end
  end

  snacks_pick(items, {
    title = "rub " .. source_label .. " → ",
    on_select = function(item)
      if item and item.target_id then
        actions.rub(source_id, item.target_id)
      end
    end,
  })
end

function M.branches()
  local items = {}

  if #state.data.unassigned > 0 then
    table.insert(items, {
      text = "unassigned",
      icon = icons.unassigned,
      icon_hl = "DiagnosticWarn",
      desc = #state.data.unassigned .. " unstaged files",
      branch = { cli_id = "zz", name = "unassigned" },
    })
  end

  for _, branch in ipairs(state.data.branches) do
    local prefix = branch.depth > 1
      and "└" .. string.rep("──", branch.depth - 1) .. " " or ""
    local commit_count = #branch.commits
    local change_count = #branch.changes
    local desc_parts = {}
    if commit_count > 0 then
      table.insert(desc_parts, commit_count .. " commit" .. (commit_count > 1 and "s" or ""))
    else
      table.insert(desc_parts, "no commits")
    end
    if change_count > 0 then
      table.insert(desc_parts, change_count .. " staged")
    end
    if branch.stack_name then
      table.insert(desc_parts, "stack: " .. branch.stack_name)
    end

    table.insert(items, {
      text = branch.name,
      icon = icons.branch,
      icon_hl = "Function",
      cli_id = branch.cli_id,
      indent = prefix,
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
  local items = {
    { text = "Mark (auto-stage)", icon = icons.mark, icon_hl = "DiagnosticHint", action = "mark" },
    { text = "Unmark", icon = icons.unmark, icon_hl = "Comment", action = "unmark" },
  }

  if branch.cli_id ~= "zz" then
    table.insert(items, { text = "Unapply", icon = icons.unapply, icon_hl = "DiagnosticWarn", action = "unapply" })
  end

  snacks_pick(items, {
    title = branch.name,
    on_select = function(item)
      if not item then
        return
      end
      if item.action == "mark" then
        actions.mark(branch.cli_id)
      elseif item.action == "unmark" then
        actions.unmark()
      elseif item.action == "unapply" then
        actions.unapply(branch.cli_id)
      end
    end,
  })
end

return M
