# emojis.nvim — Binding Cheatsheet

Every keymap, user command, and autocommand `emojis.nvim` defines. Kept in
sync with `lua/emojis/bindings/`.

Every mapping binds directly onto the public API (`require("emojis").<fn>`)
— there is no `<Plug>` indirection. which-key (if installed) only labels the
`<leader>e` prefix as a group; it does not register the individual keys.

## Preset Keymaps

Only active when `keymaps.preset = true` is set (default `false`).

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<C-e>` | n, i | `emojis.insert` | Insert picker at cursor (telescope/fzf-lua if available, else vim.ui.select) |
| `<leader>ee` | n | `emojis.overlay` | Quick-insert overlay (frecency-ordered grid) |
| `<leader>et` | n, x | `emojis.toggle` | Toggle emoji checkbox (cursor line, visual range, or the next `N` lines with a count) |
| `<leader>ec` | n | `emojis.count` | Count emojis in buffer |
| `<leader>el` | n | `emojis.list` (via `actions.list`) | List emojis in buffer -> quickfix |

**`<leader>et` takes a count**, and it widens the *scope* rather than
repeating the toggle: `3<leader>et` ticks the cursor line and the two below
it, not the cursor line three times (which would be a no-op for every even
count). This has always been the behaviour — it was documented only in a code
comment, which is what the count audit flagged.

## User Commands

Always defined, regardless of `keymaps.preset`. Built via
`lib.nvim.bindings.usercmd.composer` (`lua/emojis/commands.lua`) — a required
dependency of the command layer, unlike the soft `lib.nvim.notify`/`map`
helpers in `util/lib.lua`.

| name | args | range | desc |
| --- | --- | --- | --- |
| `:Emojis[!]` | `[action] [scope\|count\|mode\|set]` | yes | clear / replace / unreplace / wrap / list / count / insert / first / next an emoji scope (see `doc/emojis.txt`) |

`:Emojis next [count]` jumps that many emoji forward, wrapping past the last
one. It is a positional, not a command count: `:3Emojis next` would be an
address (line 3), which is not what "three emoji onward" means.

**The `!` variant** means "the alternate form of this action". The two it
applies to are disjoint, so one bang carries both without ambiguity:

- `:Emojis! toggle` steps the checkbox **backward**. `checkbox.toggle` always
  took a direction, but only the Lua API could reach the backward one.
- `:Emojis! <action> cwd` forces `--no-ignore` for that call, without
  changing `search.no_ignore`. Reaching ignored files used to mean editing
  the config and reloading, for what is usually a one-off question.

Tab completion: first argument completes `clear count first insert list next
overlay replace toggle unreplace wrap` (alphabetical, one composer route per
action), second argument completes `word line visual % cwd` (ignored for
`insert`/`first`/`next`); for `overlay` it instead completes `grid grid_keys
list`, and for `toggle` the configured `config.checkbox.sets` names.

## Autocommands

None. emojis.nvim is deliberately free of autocmd-driven behaviour (e.g. no
auto-clear on save). `lua/emojis/bindings/autocmds.lua` exists only for
structural symmetry with usrcmds/keymaps.
