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

function M.rub(source_id, target_id, callback)
  mutate({ "rub", source_id, target_id }, callback)
end

function M.stage(hunk_id, branch_id, callback)
  mutate({ "stage", hunk_id, branch_id }, callback)
end

function M.discard(id, callback)
  vim.ui.input({ prompt = "Discard " .. id .. "? (y/N): " }, function(input)
    if input and input:lower() == "y" then
      mutate({ "discard", id }, callback)
    end
  end)
end

function M.mark(target_id, callback)
  mutate({ "mark", target_id }, callback)
end

function M.unmark(callback)
  mutate({ "unmark" }, callback)
end

function M.absorb(callback)
  mutate({ "absorb" }, callback)
end

function M.undo(callback)
  mutate({ "undo" }, callback)
end

function M.branch_new(name, anchor, callback)
  local args = { "branch", "new", name }
  if anchor then
    table.insert(args, 3, "-a")
    table.insert(args, 4, anchor)
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
