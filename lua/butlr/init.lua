local config = require("butlr.config")

local M = {}

local enabled = false
local prev_signcolumn = nil
local augroup = vim.api.nvim_create_augroup("butlr", { clear = true })

function M.setup(opts)
  config.setup(opts)
end

function M.enable()
  if enabled then
    return
  end
  enabled = true

  local state = require("butlr.state")
  local vt = require("butlr.virtual_text")

  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "ButlrStateChanged",
    callback = function()
      vt.render_all_visible()
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.bo.buftype == "" then
        state.refresh()
      end
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      state.refresh_now()
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      if vim.bo.buftype == "" then
        vt.render_current()
      end
    end,
  })

  if config.options.signs.enabled then
    prev_signcolumn = vim.o.signcolumn
    local cur = vim.o.signcolumn
    -- Widen to auto:2 so butlr and gitsigns each get their own column
    if cur == "auto" or cur == "yes" or cur == "auto:1" or cur == "yes:1" then
      vim.o.signcolumn = "auto:2"
    end
  end

  state.refresh_now()
end

function M.disable()
  if not enabled then
    return
  end
  enabled = false
  vim.api.nvim_clear_autocmds({ group = augroup })

  if prev_signcolumn then
    vim.o.signcolumn = prev_signcolumn
    prev_signcolumn = nil
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      require("butlr.virtual_text").clear(buf)
    end
  end
end

function M.is_enabled()
  return enabled
end

return M
