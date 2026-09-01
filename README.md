# butlr.nvim

[GitButler](https://gitbutler.com/) integration for Neovim. See which virtual
branch each hunk belongs to, right in the buffer — and reassign, commit, or
unapply branches without leaving your editor.

butlr activates automatically in any repository managed by GitButler and stays
out of the way everywhere else.

## Features

- **Inline hunk attribution** — signs + end-of-line virtual text show the
  branch each changed hunk is assigned to (or that it's still unassigned).
- **Assign picker** — route the hunk/file under the cursor onto another branch,
  amend it into a commit, or uncommit it back into the working tree.
- **Branch picker** — absorb, commit uncommitted changes onto a branch, discard,
  and unapply.
- **Hunk navigation** — jump between hunks in the current file or across the
  whole worktree.
- **Statusline component** — active branches, unassigned count, conflict flag.
- **Auto-detect** — enables on `VimEnter`/`DirChanged` when a GitButler repo is
  found, disables otherwise.

## Requirements

- Neovim ≥ 0.10 (uses `vim.system` and `vim.uv`)
- [GitButler](https://gitbutler.com/) with the `but` CLI on your `$PATH`,
  **version 0.22.x** (see [Supported `but` versions](#supported-but-versions))
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
  cli = {
    check_version = true,              -- refuse to enable on an unsupported `but`
    min_version = "0.22.0",
    max_tested_version = "0.22",       -- newer minors only warn
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
vim.keymap.set("n", "<leader>br", function() require("butlr.picker").assign() end,   { desc = "butlr: reassign hunk/file" })
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

`require("butlr.actions")` wraps the `but` CLI directly: `amend`, `commit`,
`squash`, `move`, `move_to_branch`, `uncommit`, `discard`, `absorb`, `undo`,
`branch_new`, `apply`, `unapply`. Each takes an optional trailing `callback`.

## Supported `but` versions

butlr targets the `but` **0.22.x** command surface and refuses to enable outside
it, because an unsupported CLI fails silently rather than loudly — every JSON
read errors out and the buffer simply shows no hunks.

The pinned range lives in `opts.cli`; raise `max_tested_version` yourself if you
want to try a newer `but`, or set `check_version = false` to skip the guard.

Notable upstream changes butlr tracks:

| Older `but` | 0.22.x |
|---|---|
| global `-j` / `--status-after` | per-subcommand `--json` / `--status-after` |
| `status.unassignedChanges` | `status.uncommittedChanges` |
| `but rub <src> <tgt>` | `but squash -t`, `but move`, `but amend` |
| `but stage <hunk> <branch>` | `but amend -t <branch>` / `but commit -b <branch>` |
| `but mark` / `but unmark` | removed upstream, no replacement |
| `but branch new -a <anchor>` | `but branch new -A/-B <anchor>` |

## How it works

butlr shells out to `but <cmd> --json`, parses `but status -f` plus per-branch
and per-commit diffs, and renders the result as extmark signs and virtual text.
Committed file IDs come from `status -f` (`commits[].changes[].cliId`) since
`but diff <commit>` does not emit them. State refreshes on `BufWritePost`,
`FocusGained`, and after any mutating action.

## License

[MIT](./LICENSE)
