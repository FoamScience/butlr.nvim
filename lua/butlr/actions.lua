local cli = require("butlr.cli")
local state = require("butlr.state")

local M = {}

local function mutate(args, callback)
  cli.run(args, {
    status_after = true,
    on_success = function(data)
      if data.status then
        state.update_from_status_after(data.status)
      else
        state.update_from_status_after(data)
      end
      if callback then
        callback(data.result or data)
      end
    end,
  })
end

--- Amend uncommitted file/hunk IDs into a commit, or into a branch's tip commit.
---@param target string commit or branch CLI ID
---@param sources string[]
function M.amend(target, sources, callback)
  local args = { "amend", "-t", target }
  vim.list_extend(args, sources)
  mutate(args, callback)
end

--- Commit uncommitted file/hunk IDs onto a branch, creating it if needed.
---@param branch string
---@param message string
---@param sources string[]
function M.commit(branch, message, sources, callback)
  local args = { "commit", "-b", branch, "-m", message }
  vim.list_extend(args, sources)
  mutate(args, callback)
end

--- Squash sources (commits, branches or uncommitted changes) into a target.
---@param sources string[]
---@param target string
---@param message? string required when sources are commits or branches
function M.squash(sources, target, message, callback)
  local args = { "squash" }
  vim.list_extend(args, sources)
  vim.list_extend(args, { "-t", target })
  if message then
    vim.list_extend(args, { "-m", message })
  end
  mutate(args, callback)
end

--- Move commits, committed files or a branch onto a branch.
---@param sources string[]
---@param branch string
function M.move_to_branch(sources, branch, callback)
  local args = { "move" }
  vim.list_extend(args, sources)
  vim.list_extend(args, { "-b", branch })
  mutate(args, callback)
end

--- Move a source above/below an anchor commit or branch.
---@param sources string[]
---@param placement "above"|"below"|"unstack"
---@param anchor? string
function M.move(sources, placement, anchor, callback)
  local args = { "move" }
  vim.list_extend(args, sources)
  if placement == "unstack" then
    table.insert(args, "--unstack")
  else
    vim.list_extend(args, { placement == "above" and "--above" or "--below", anchor })
  end
  mutate(args, callback)
end

--- Uncommit a commit, a branch, or a single committed file (`<commit>:<file>`).
---@param id string
function M.uncommit(id, callback)
  mutate({ "uncommit", id }, callback)
end

function M.discard(id, callback)
  vim.ui.input({ prompt = "Discard " .. id .. "? (y/N): " }, function(input)
    if input and input:lower() == "y" then
      mutate({ "discard", id }, callback)
    end
  end)
end

function M.absorb(callback)
  mutate({ "absorb" }, callback)
end

function M.undo(callback)
  mutate({ "undo" }, callback)
end

---@param name string
---@param anchor? string
---@param placement? "above"|"below" defaults to "above"
function M.branch_new(name, anchor, placement, callback)
  local args = { "branch", "new", name }
  if anchor then
    vim.list_extend(args, { placement == "below" and "-B" or "-A", anchor })
  end
  mutate(args, callback)
end

function M.apply(branch_id, callback)
  mutate({ "apply", branch_id }, callback)
end

function M.unapply(branch_id, callback)
  mutate({ "unapply", branch_id }, callback)
end

return M
