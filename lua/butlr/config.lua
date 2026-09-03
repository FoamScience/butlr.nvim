local M = {}

---@class butlr.Config
local defaults = {
  refresh_debounce_ms = 200,
  cli = {
    -- butlr is written against the `but` CLI surface below; outside this range
    -- flags and subcommands differ enough to produce silently empty state.
    check_version = true,
    min_version = "0.22.0",
    max_tested_version = "0.22",
  },
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
M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
