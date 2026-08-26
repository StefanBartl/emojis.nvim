# Features

Everything `emojis.nvim` does, in one file — a single `:Emojis` command
plus a handful of internal areas (scopes, overlay, checkboxes), so a
theme split would only add navigation for its own sake. See
[`docs/FEATURES_FORMAT.md`](https://github.com/StefanBartl/documentation.nvim/blob/main/docs/FEATURES_FORMAT.md)
(in `documentation.nvim`) for the format this file follows.

## `:Emojis` — the single entry point

One command, `[action] [scope]`, dispatching to a shared `execute()`
function. Bare `:Emojis` is `:Emojis clear %` (remove every emoji in the
buffer). Actions: `clear`, `replace`, `unreplace`, `wrap`, `list`,
`count`, `insert`, `overlay`, `toggle`, `first`, `next`. Scopes: `%`
(buffer, default), `line`, `word`, `visual`, `cwd` (project-wide via
ripgrep). An explicit Vim range (`:'<,'>Emojis`, `:10,20Emojis`) overrides
the scope keyword. Built via `lib.nvim.bindings.usercmd.composer` — one route per
action, forwarding to `emojis.commands`'s `execute()`.

- **Module:** `lua/emojis/commands.lua` (`M.execute`),
  `lua/emojis/bindings/usrcmds.lua`
- **Usercmds:** `:[range]Emojis [action] [scope]`
  ([BINDINGS.md](BINDINGS.md#user-commands))
- **Config:** `opts.default_scope` (default `"%"`), `opts.command`
  (default `"Emojis"`, renameable)

## Pure UTF-8 emoji detection

Emoji detection runs on a pure UTF-8 byte tokenizer, no external library
and no shell-out for the buffer/line/word/visual scopes. VS16 sequences
(e.g. `⚠️`) are correctly treated as **one** emoji, not two — a fixed bug
relative to the plugin this replaced, which counted them twice and turned
one glyph into two `replace` placeholders.

- **Module:** `lua/emojis/core/patterns.lua`
- **Config:** none

## Clear / replace / unreplace / wrap / list / count

`clear` removes emojis in scope, collapsing the surrounding double space
(`SPACE EMOJI SPACE` → `SPACE SPACE`, not two spaces) down to one on both
sides of a removed emoji or emoji run — a fixed bug relative to the old
behavior. `replace` swaps emojis for `:name:` placeholders; `unreplace`
reverses it. `wrap` surrounds emojis with a configurable marker without
removing them. `list` collects every emoji in scope into the quickfix
list; `count` reports how many there are.

- **Module:** `lua/emojis/core/ops.lua`, `lua/emojis/actions.lua`
- **Usercmds:** `:Emojis clear|replace|unreplace|wrap|list|count [scope]`
  ([commands.md](commands.md))
- **Config:** `opts.names` (codepoint → `:name:` map, derived from
  `opts.picks`), `opts.wrap.prefix`/`opts.wrap.suffix` (default `"[["`/
  `"]]"`)

## Change preview before clear/replace

`preview.enable = true` briefly highlights (default 150ms,
`preview.hl_group`, default `"IncSearch"`) the emojis about to be
affected before `clear`/`replace` actually mutates the buffer — a look-
before-you-leap step, off by default.

- **Module:** `lua/emojis/core/ops.lua`
- **Config:** `opts.preview.enable` (default `false`),
  `opts.preview.duration_ms` (default `150`), `opts.preview.hl_group`
  (default `"IncSearch"`)

## Project-wide `cwd` scope via ripgrep

`clear`/`replace`/`list`/`count` accept `cwd` as a scope, searching the
whole project asynchronously via ripgrep instead of just the open buffer.
`clear cwd`/`replace cwd` ask for confirmation before every change
(default: cancel) — `list cwd` first is the recommended dry run. Buffers
already open with unsaved changes are skipped, not overwritten, and
counted as "skipped" in the summary. Extra arguments after `cwd` pass
through to ripgrep as `--glob` filters.

- **Tab:** true
- **Module:** `lua/emojis/search.lua`
- **Usercmds:** `:Emojis clear|replace|list|count cwd [glob...]`
  ([commands.md](commands.md))
- **Config:** `opts.search.cmd` (default `"rg"`),
  `opts.search.extra_args`, `opts.search.no_ignore` (default `false`,
  set `true` to also search gitignored files via `--no-ignore`)

### Why a confirmation gate, and why it defaults to cancel

`cwd` is the one scope that touches files outside the current buffer,
including files not currently open in the editor — an accidental
`:Emojis clear cwd` without the gate could silently rewrite the whole
project. Defaulting the confirmation dialog to "cancel" means a stray
`<CR>` doesn't accidentally confirm a project-wide rewrite; running
`list cwd` first to see the blast radius before ever reaching for
`clear cwd`/`replace cwd` is the documented, recommended order.

## Insert picker

`:Emojis insert` opens a fuzzy picker at the cursor over the full catalog
(60+ entries, `opts.picks`), inserting the chosen glyph. Engine
auto-detected (`picker.engine = "auto"`): telescope.nvim or fzf-lua if
installed, else `vim.ui.select`. Every insertion — from here and from the
overlay — is recorded for frecency-based overlay reordering.

- **Module:** `lua/emojis/picker.lua`
- **Usercmds:** `:Emojis insert`
- **Keymaps:** `<C-e>` (normal, insert — `keymaps.preset = true`)
- **Config:** `opts.picker.engine` (`"auto"`|`"telescope"`|`"fzf-lua"`|
  `"select"`, default `"auto"`), `opts.picks`

## Quick-insert overlay

`:Emojis overlay [grid|grid_keys|list]` opens a small float holding
~20 curated emojis (`opts.overlay.picks`, `opts.overlay.limit`), meant to
be opened and dismissed in a second or two — unlike `insert`, which
searches the full catalog. `grid` mode: `h`/`j`/`k`/`l`/arrows move,
`<CR>` inserts. `grid_keys`: same grid, plus a direct hotkey per cell —
one keypress inserts. `list`: one glyph per row with its shortcode via
the `lib.nvim` kit chooser. `<Esc>`/`q` closes without inserting. The
mode argument overrides `opts.overlay.mode` for that one invocation.

### Type-to-filter in the grid (2026-08-24)

`/` in either grid mode prompts for a filter and re-renders with only the
matching emojis; an empty query widens back to the full set. It matches the
shortcode, and the glyph itself, so pasting an emoji narrows to it. Closes
the flag/option audit's entry — `list` mode has had filtering via
`kit.chooser` from the start, and the grid had no way to narrow at all, so
finding one glyph in a full grid meant scanning it by eye.

A prompt behind `/` rather than a live input line: the grid is a
fixed-layout hotkey surface — in `grid_keys` every printable key is already
an insert action — so an input line would make it a different widget. `/` is
the obvious key for "narrow this" and is not a hotkey.

Filtering re-opens the float rather than patching the buffer in place: the
cell byte-spans and the per-cell hotkeys are both derived from the item list,
so rebuilding is the only way to keep all three in step. The unfiltered set
is kept in state, so a second filter widens from the original list instead of
compounding onto the first.

- **Module:** `lua/emojis/overlay/init.lua`
- **Usercmds:** `:Emojis overlay [grid|grid_keys|list]`
  ([commands.md](commands.md))
- **Keymaps:** `<leader>ee` (normal — `keymaps.preset = true`)
- **Config:** `opts.overlay.mode` (default `"grid"`),
  `opts.overlay.columns` (default `5`), `opts.overlay.limit` (default
  `20`), `opts.overlay.title`, `opts.overlay.theme` (any `lib.nvim.ui.kit`
  theme arg), `opts.overlay.picks` (replaces, does not merge with, the
  default list)

## Frecency-based overlay reordering

With `overlay.frecency = true` (default), every insertion — overlay and
insert-picker alike — is counted and the overlay grid re-sorts most-used-
first with a 30-day recency half-life. Ties keep the configured order, so
the grid doesn't shuffle unpredictably under the cursor. Only ever
*reorders* `overlay.picks` — never adds or removes glyphs beyond what was
configured. Usage is persisted as JSON under
`stdpath("data")/emojis.nvim/frecency.json`; `require("emojis.overlay.frecency").reset()`
clears the history.

- **Module:** `lua/emojis/overlay/frecency.lua`
- **Config:** `opts.overlay.frecency` (default `true`)

## Emoji checkboxes

`:Emojis toggle [set]` cycles a glyph found anywhere on the line (not
just under the cursor) one step through a named set, e.g.
`🔲 1. Hallo` → `✅ 1. Hallo`. Unlike other actions, the second argument is
a **set name**, not a scope, and the scope is always a line range — an
explicit Vim range, or else the cursor line/visual selection — never
`word`, `%`, or `cwd`, since a checkbox belongs to a whole line and
defaulting wider would silently flip every box in the file. With no `set`
given, searches through `checkbox.order` (defaults: `checkbox`, `status`,
`review` — deliberately disjoint, so an unqualified toggle stays
unambiguous). `checkbox_add`/`checkbox_remove` (Lua API only) add or strip
a checkbox from a line that doesn't have one yet, rather than cycling an
existing one.

- **Module:** `lua/emojis/core/checkbox.lua`
- **Usercmds:** `:[range]Emojis toggle [set]` ([commands.md](commands.md))
- **Keymaps:** `<leader>et` (normal, visual — `keymaps.preset = true`)
- **Config:** `opts.checkbox.sets` (default `checkbox`/`status`/
  `review`), `opts.checkbox.default_set` (default `""` = search every
  set), `opts.checkbox.order` (search order; sets omitted here are still
  searched, appended in name-sorted order)

## cascade.nvim bridge

`require("emojis").cascade_groups()` returns `config.checkbox.sets` in
[cascade.nvim](https://github.com/StefanBartl/cascade.nvim)'s
`cycle.groups` format, so the same glyph vocabulary drives both plugins
without listing it twice — cascade's `<C-y>` cycles the glyph the cursor
is *on* (cursor-precise), `:Emojis toggle`/`<leader>et` cycles whichever
configured glyph is anywhere on the line (line-scoped). A pure data
function — never `require("cascade")` itself, so it's safe to call
whether or not cascade.nvim is installed.

- **Module:** `lua/emojis/init.lua` (`M.cascade_groups`)
- **Config:** none — reads `opts.checkbox.sets`

## Cursor navigation (`first` / `next`)

`:Emojis first` jumps the cursor to the first emoji in the buffer;
`:Emojis next` jumps to the next one, wrapping to the top at the end of
the buffer. Pure navigation — neither mutates the buffer.

- **Module:** `lua/emojis/nav.lua`
- **Usercmds:** `:Emojis first`, `:Emojis next`

## Which-key group labeling

When `keymaps.preset = true`, the `<leader>e` group is automatically
labeled in which-key.nvim if installed — an optional dependency, silently
skipped if which-key isn't present.

- **Module:** `lua/emojis/bindings/which_key.lua`
- **Config:** `opts.keymaps.preset` (default `false`)

## Lua API for scripts and tests

`require("emojis").ops()` exposes the pure clear/count/list/replace
functions directly on plain string arrays, with no Neovim API calls — for
use in headless scripts and tests without a real buffer.

- **Module:** `lua/emojis/core/ops.lua`, `lua/emojis/init.lua` (`M.ops`)
- **Docs:** [api.md](api.md)

## `:checkhealth emojis`

Checks `lib.nvim` (required — the `:Emojis` command layer depends on it),
ripgrep availability (for `cwd` scope), and picker engine detection.

- **Module:** `lua/emojis/health.lua`
