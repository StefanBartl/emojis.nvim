# emojis.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `emojis.nvim`. This file is documentation only and mirrors the
source of truth in `lua/emojis/bindings/`. Any change there must be reflected
here.

Every mapping binds directly onto the public API (`require("emojis").<fn>`)
— there is no `<Plug>` indirection. which-key (if installed) only labels the
`<leader>e` prefix as a group; it does not register the individual keys.

## Preset Keymaps

Only active when `keymaps.preset = true` is set (default `false`).

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<C-e>` | n, i | `emojis.insert` | Insert picker at cursor |
| `<leader>ec` | n | `emojis.count` | Count emojis in buffer |
| `<leader>el` | n | `emojis.list` (via `actions.list`) | List emojis in buffer -> quickfix |

## User Commands

Always defined, regardless of `keymaps.preset`.

| name | args | range | desc |
| --- | --- | --- | --- |
| `:Emojis` | `[action] [scope]` | yes | clear / replace / unreplace / wrap / list / count / insert / first / next an emoji scope (see `doc/emojis.txt`) |

Tab completion: first argument completes `clear insert list count replace unreplace first next wrap`,
second argument completes `word line visual % cwd` (ignored for `insert`/`first`/`next`).

## Autocommands

None. emojis.nvim is deliberately free of autocmd-driven behaviour (e.g. no
auto-clear on save) — see "Nicht geplant" in [`docs/ROADMAP.md`](ROADMAP.md).
`lua/emojis/bindings/autocmds.lua` exists only for structural symmetry with
usrcmds/keymaps.
