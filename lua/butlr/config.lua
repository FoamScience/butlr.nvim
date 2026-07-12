local M = {}

---@class butlr.Config
local defaults = {
  refresh_debounce_ms = 200,
  virtual_text = {
    enabled = true,
    hl_group = "Comment",
    unassigned_hl_group = "DiagnosticWarn",
    icon = "󰊢",
    min_col = 100,
  },
  signs = {
    enabled = true,
    assigned = { text = "▎", hl = "ButlrSignAssigned" },
    unassigned = { text = "▎", hl = "ButlrSignUnassigned" },
    conflict = { text = "▎", hl = "ButlrSignConflict" },
  },
  picker = {
    ---@type "snacks"
    backend = "snacks",
  },
  notify_conflicts = true,
}

---@type butlr.Config
M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
