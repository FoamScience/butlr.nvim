local state = require("butlr.state")

local M = {}

function M.is_active()
  return require("butlr.detect").is_gitbutler()
end

function M.branch_info()
  local branches = {}
  for _, b in ipairs(state.data.branches) do
    table.insert(branches, {
      name = b.name,
      cli_id = b.cli_id,
      commits = #b.commits,
      changes = #b.changes,
      stack = b.stack_name,
    })
  end
  return {
    branches = branches,
    unassigned = #state.data.unassigned,
    active_mark = state.data.active_mark,
    conflicted = state.data.conflicted,
  }
end

function M.hunk_summary()
  local total = 0
  local by_branch = {}
  for _, file_data in pairs(state.data.hunks) do
    local count = #file_data.hunks
    total = total + count
    local branch = file_data.branch_name or "unassigned"
    by_branch[branch] = (by_branch[branch] or 0) + count
  end
  return {
    total = total,
    by_branch = by_branch,
  }
end

function M.component()
  if not M.is_active() then
    return ""
  end
  local info = M.branch_info()
  local parts = {}
  for _, b in ipairs(info.branches) do
    table.insert(parts, b.name)
  end
  if info.unassigned > 0 then
    table.insert(parts, "+" .. info.unassigned)
  end
  if info.conflicted then
    table.insert(parts, "!")
  end
  return table.concat(parts, " │ ")
end

return M
