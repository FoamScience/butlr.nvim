local config = require("butlr.config")
local state = require("butlr.state")

local M = {}

local ns = vim.api.nvim_create_namespace("butlr")

local hl_defined = false
local function ensure_highlights()
  if hl_defined then
    return
  end
  hl_defined = true
  -- Thin colored bars that sit beside gitsigns' default signs.
  -- Gitsigns uses GitSigns{Add,Change,Delete} → green/blue/red bars.
  -- Butlr uses distinct hues: purple for assigned, yellow for unassigned, red for conflict.
  vim.api.nvim_set_hl(0, "ButlrSignAssigned", { default = true, fg = "#b48ead" })
  vim.api.nvim_set_hl(0, "ButlrSignUnassigned", { default = true, fg = "#ebcb8b" })
  vim.api.nvim_set_hl(0, "ButlrSignConflict", { default = true, fg = "#bf616a" })
  vim.api.nvim_set_hl(0, "ButlrHunkId", { default = true, fg = "#88c0d0", bold = true })
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.render(buf)
  M.clear(buf)
  ensure_highlights()

  local file = vim.api.nvim_buf_get_name(buf)
  local rel = vim.fn.fnamemodify(file, ":.")
  local file_data = state.data.hunks[rel]
  if not file_data then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local vt_enabled = config.options.virtual_text.enabled
  local signs_enabled = config.options.signs.enabled
  local prefix = config.options.virtual_text.prefix
  local signs = config.options.signs

  for _, hunk in ipairs(file_data.hunks) do
    local branch = hunk.branch_name
    local added = hunk.added_lines or {}
    local removed_at = hunk.removed_at or {}

    -- Collect all changed lines (added + deletion points) for signs and virtual text
    local changed = {}
    for _, l in ipairs(added) do
      changed[l] = "add"
    end
    for _, l in ipairs(removed_at) do
      if not changed[l] then
        changed[l] = "del"
      else
        changed[l] = "change"
      end
    end

    -- Find first changed line for virtual text placement
    local first_changed
    if #added > 0 then
      first_changed = added[1]
    elseif #removed_at > 0 then
      first_changed = removed_at[1]
    else
      first_changed = hunk.new_start
    end

    -- Virtual text at first actual change
    if vt_enabled then
      local vt_line = first_changed - 1
      if vt_line >= 0 and vt_line < line_count then
        local icon = config.options.virtual_text.icon
        local min_col = config.options.virtual_text.min_col
        local line_text = vim.api.nvim_buf_get_lines(buf, vt_line, vt_line + 1, false)[1] or ""
        local line_len = vim.fn.strdisplaywidth(line_text)
        local pad = math.max(2, min_col - line_len)
        local spacing = string.rep(" ", pad)

        local hl = branch and config.options.virtual_text.hl_group
          or config.options.virtual_text.unassigned_hl_group
        local branch_label = branch or "unassigned"

        vim.api.nvim_buf_set_extmark(buf, ns, vt_line, 0, {
          virt_text = {
            { spacing },
            { icon .. " ", hl },
            { hunk.id, "ButlrHunkId" },
            { " │ ", "NonText" },
            { branch_label, hl },
          },
          virt_text_pos = "eol",
          priority = 50,
        })
      end
    end

    -- Signs only on actually changed lines
    if signs_enabled then
      local sign = branch and signs.assigned or signs.unassigned
      for line_nr, _ in pairs(changed) do
        local line = line_nr - 1
        if line >= 0 and line < line_count then
          vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
            sign_text = sign.text,
            sign_hl_group = sign.hl,
            priority = 8,
          })
        end
      end
    end
  end
end

function M.render_current()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == "" then
    M.render(buf)
  end
end

function M.render_all_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" then
      M.render(buf)
    end
  end
end

return M
