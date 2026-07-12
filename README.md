# butlr.nvim

[GitButler](https://gitbutler.com/) integration for Neovim. See which virtual
branch each hunk belongs to, right in the buffer — and reassign, mark, or
unapply branches without leaving your editor.

butlr activates automatically in any repository managed by GitButler and stays
out of the way everywhere else.

## Features

- **Inline hunk attribution** — signs + end-of-line virtual text show the
  branch each changed hunk is assigned to (or that it's still unassigned).
- **`rub` picker** — move the hunk/file under the cursor to another branch,
  the unassigned pool, or amend it into a commit.
- **Branch picker** — mark (auto-stage), unmark, and unapply branches.
- **Hunk navigation** — jump between hunks in the current file or across the
  whole worktree.
- **Statusline component** — active branches, unassigned count, conflict flag.
- **Auto-detect** — enables on `VimEnter`/`DirChanged` when a GitButler repo is
  found, disables otherwise.

## Requirements

- Neovim ≥ 0.10 (uses `vim.system` and `vim.uv`)
- [GitButler](https://gitbutler.com/) with the `but` CLI on your `$PATH`
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) — for the pickers

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "FoamScience/butlr.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {},
}
```

`opts = {}` runs `require("butlr").setup()` with the defaults below. butlr does
not define any commands or keymaps — wire the Lua functions to your own
mappings (see [Usage](#usage)).

## Configuration

Defaults:

```lua
require("butlr").setup({
  refresh_debounce_ms = 200,
  virtual_text = {
    enabled = true,
    hl_group = "Comment",              -- assigned hunks
    unassigned_hl_group = "DiagnosticWarn",
    icon = "󰊢",
    min_col = 100,                     -- column the virtual text aligns to
  },
  signs = {
    enabled = true,
    assigned = { text = "▎", hl = "ButlrSignAssigned" },
    unassigned = { text = "▎", hl = "ButlrSignUnassigned" },
    conflict = { text = "▎", hl = "ButlrSignConflict" },
  },
  picker = {
    backend = "snacks",
  },
  notify_conflicts = true,             -- notify when conflicted commits appear
})
```

### Highlights

Defined with `default = true`, so a colorscheme can override them:

| Group | Purpose | Default |
|-------|---------|---------|
| `ButlrSignAssigned` | assigned-hunk sign | `#b48ead` |
| `ButlrSignUnassigned` | unassigned-hunk sign | `#ebcb8b` |
| `ButlrSignConflict` | conflict sign | `#bf616a` |
| `ButlrHunkId` | hunk id in pickers/virtual text | `#88c0d0` |

## Usage

butlr exposes a Lua API; bind what you use. Example keymaps:

```lua
vim.keymap.set("n", "<leader>br", function() require("butlr.picker").rub() end,      { desc = "butlr: reassign hunk/file" })
vim.keymap.set("n", "<leader>bb", function() require("butlr.picker").branches() end, { desc = "butlr: branches" })
vim.keymap.set("n", "]h",         function() require("butlr.navigation").next_hunk() end, { desc = "butlr: next hunk" })
vim.keymap.set("n", "[h",         function() require("butlr.navigation").prev_hunk() end, { desc = "butlr: prev hunk" })
vim.keymap.set("n", "]H",         function() require("butlr.navigation").next_hunk_global() end, { desc = "butlr: next hunk (repo)" })
vim.keymap.set("n", "[H",         function() require("butlr.navigation").prev_hunk_global() end, { desc = "butlr: prev hunk (repo)" })
```

### Statusline

```lua
require("butlr.statusline").component()  -- e.g. "feat-a │ feat-b │ +2 │ !"
```

`require("butlr.statusline").branch_info()` and `.hunk_summary()` return
structured tables if you want to build your own component.

### Actions (Lua)

`require("butlr.actions")` wraps the `but` CLI directly: `rub`, `stage`,
`discard`, `mark`, `unmark`, `absorb`, `undo`, `branch_new`, `apply`,
`unapply`. Each takes an optional trailing `callback`.

## How it works

butlr shells out to `but -j` (JSON output), parses status and per-branch diffs,
and renders the result as extmark signs and virtual text. State refreshes on
`BufWritePost`, `FocusGained`, and after any mutating action.

## License

[MIT](./LICENSE)
