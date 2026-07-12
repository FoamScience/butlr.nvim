local state = require("butlr.state")

local M = {}

local function first_changed_line(hunk)
  if hunk.added_lines and #hunk.added_lines > 0 then
    return hunk.added_lines[1]
  end
  if hunk.removed_at and #hunk.removed_at > 0 then
    return hunk.removed_at[1]
  end
  return hunk.new_start
end

local function get_hunks_for_current_buf()
  local file = vim.api.nvim_buf_get_name(0)
  local rel = vim.fn.fnamemodify(file, ":.")
  local file_data = state.data.hunks[rel]
  if not file_data or #file_data.hunks == 0 then
    return nil
  end
  return file_data.hunks
end

function M.next_hunk()
  local hunks = get_hunks_for_current_buf()
  if not hunks then
    vim.notify("[butlr] no hunks in this file", vim.log.levels.INFO)
    return
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  for _, hunk in ipairs(hunks) do
    local target = first_changed_line(hunk)
    if target > cursor_line then
      vim.api.nvim_win_set_cursor(0, { target, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { first_changed_line(hunks[1]), 0 })
end

function M.prev_hunk()
  local hunks = get_hunks_for_current_buf()
  if not hunks then
    vim.notify("[butlr] no hunks in this file", vim.log.levels.INFO)
    return
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  for i = #hunks, 1, -1 do
    local target = first_changed_line(hunks[i])
    if target < cursor_line then
      vim.api.nvim_win_set_cursor(0, { target, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { first_changed_line(hunks[#hunks]), 0 })
end

local function get_all_hunks_sorted()
  local all = {}
  for path, file_data in pairs(state.data.hunks) do
    for _, hunk in ipairs(file_data.hunks) do
      table.insert(all, { path = path, line = first_changed_line(hunk), hunk = hunk })
    end
  end
  table.sort(all, function(a, b)
    if a.path == b.path then
      return a.line < b.line
    end
    return a.path < b.path
  end)
  return all
end

local function jump_to(entry)
  vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
  vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
end

function M.next_hunk_global()
  local all = get_all_hunks_sorted()
  if #all == 0 then
    vim.notify("[butlr] no hunks in repo", vim.log.levels.INFO)
    return
  end

  local cur_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]

  for _, entry in ipairs(all) do
    if entry.path > cur_file or (entry.path == cur_file and entry.line > cur_line) then
      jump_to(entry)
      return
    end
  end
  jump_to(all[1])
end

function M.prev_hunk_global()
  local all = get_all_hunks_sorted()
  if #all == 0 then
    vim.notify("[butlr] no hunks in repo", vim.log.levels.INFO)
    return
  end

  local cur_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]

  for i = #all, 1, -1 do
    local entry = all[i]
    if entry.path < cur_file or (entry.path == cur_file and entry.line < cur_line) then
      jump_to(entry)
      return
    end
  end
  jump_to(all[#all])
end

return M
