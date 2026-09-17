# Tests

Headless spec suite for emojis.nvim. The tokenizer/ops/scope layers are pure
functions on strings — trivially testable without a UI — and everything above
them is tested against real buffers, real keymaps and the real `:Emojis`
command, with only the two optional picker backends and the ripgrep process
replaced by doubles.

`commands_spec.lua` calls `emojis.setup()`, which registers `:Emojis` via
`lib.nvim.bindings.usercmd.composer` — a real runtime dependency as of that
migration, not an optional extra. Check out `lib.nvim` as a sibling of this
repo (same convention as every other `StefanBartl/*.nvim` repo's test suite)
and add it to the runtimepath.

`picker_spec.lua` (via `ui.kit.select`'s `respect_override` passthrough to
`vim.ui.select`), `overlay_spec.lua` and `overlay_modes_spec.lua`
(`overlay.open("grid")` actually opens the float) all need a real `ui.kit`,
which moved out of `lib.nvim` into the separate `ui.nvim` repo in the 2026-09
migration — check that out as a sibling too.

## Run

From the repo root, with `../lib.nvim` and `../ui.nvim` checked out as siblings:

```sh
nvim --headless -u NONE -c "set rtp+=.,../lib.nvim,../ui.nvim" -c "luafile TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec with the number of assertions it executed,
a total, and exits non-zero on the first failure (`EMOJIS_TESTS_OK` on
success).

## No subprocesses, no network

Nothing in this suite spawns a process. The three places the plugin would are
each cut at one seam, replaced *before* the code under test runs:

| Real thing | Seam | Spec |
| --- | --- | --- |
| `rg`, via `vim.system` | `vim.system` / `vim.fn.executable` | `search_run_spec.lua` |
| `rg`, on a Neovim without `vim.system` | `vim.fn.jobstart` | `search_run_spec.lua` |
| telescope.nvim / fzf-lua | `package.loaded["telescope.*"]`, `package.loaded["fzf-lua"]` | `picker_engine_spec.lua`, `health_spec.lua` |

The same technique covers the "dependency is not installed" branches: a
`package.preload` entry that raises makes `require` fail, which is how the
`ui.kit`-less overlay, the `lib.nvim`-less `util/lib.lua` fallbacks and the
missing-composer health branch are reached on a machine that *has* all three.

Writes to disk stay inside `vim.fn.tempname()` directories. The frecency store
is redirected to a temp file by `run.lua` before any spec runs, so a suite run
never mutates the developer's real usage history under `stdpath("data")`.

## Layout

| File | Covers |
| --- | --- |
| `harness.lua` | Shared assertions (`eq`, `ok`), the assertion counter, `scratch(ft)` buffers, and `notices(fn)` — which captures what `emojis.util.notify` said. |
| `run.lua` | Runner: loads every spec in order, reports per-spec and total assertion counts, sets the exit code. |
| `patterns_spec.lua` | Tokenizer: base matching, VS16, skin tone, ZWJ chains, flag pairing, `match_at` anchoring, `encode`/`codepoint` round-trips. |
| `ops_spec.lua` | `clear`/`replace`/`unreplace`/`wrap`/`count`/`list` on string arrays: space-collapse rules, stray VS16, default arguments, unknown `:token:` handling. |
| `checkbox_spec.lua` | Checkbox cycle/add/remove: line-scoped find, wrap in both directions, ambiguous-set resolution, indentation, VS16 glyphs. |
| `scope_spec.lua` | Scope resolution: `%`, `line`, `word` (including tabs and line edges), `visual`, range override and clamping, `cwd`. |
| `config_spec.lua` | DEFAULTS catalog: `picks`/`names` stay in sync, no codepoint collisions. |
| `config_merge_spec.lua` | The runtime store: merge semantics (lists replace, maps merge), validation fallbacks, `get()` before `setup()`, `checkbox_sets()` ordering and refusals. |
| `insert_spec.lua` | `core.insert`: byte-exact insertion next to multibyte neighbours, cursor advance, rejections, frecency recording (and opting out of it). |
| `nav_spec.lua` | `first`/`next`: byte columns, wrap-around, counted walks, and which of them report "no emoji found". |
| `util_lib_spec.lua` | The guarded `lib.nvim` bridge and `util/notify.lua`, each on both paths (helper present / absent). |
| `actions_spec.lua` | The buffer-facing handlers: all four `edit` actions, the `word` sub-range arithmetic, the quickfix shape, `count` wording, every checkbox branch and refusal. |
| `commands_spec.lua` | `:Emojis` end to end: unreplace, first/next, wrap, the preview extmarks, `next [count]`, the two `!` variants, `word` scope. |
| `commands_dispatch_spec.lua` | The dispatch layer: validation refusals, the NO_SCOPE bypass, routing to picker/overlay/nav/search, range precedence, and completion at each position. |
| `search_spec.lua` | `build_cmd()` glob/no_ignore flags; `apply_across_files()` confirm-gated cwd clear/replace against real files. |
| `search_run_spec.lua` | `run()`/`finish()`: the guards before the spawn, the chunked line collector (both transports), the four result shapes, two pinned bugs. |
| `picker_spec.lua` | Insert picker: engine selection falls back to `vim.ui.select`, with and without `ui.kit`. |
| `picker_engine_spec.lua` | The engine matrix against telescope/fzf-lua doubles: entry shapes, selection callbacks, explicit-engine misses. |
| `frecency_spec.lua` | The usage store: path, persistence, degraded files, decay arithmetic, `reset()`, and one pinned bug. |
| `overlay_spec.lua` | Quick-insert overlay: grid/grid_keys/list modes, frecency reordering, config validation. |
| `overlay_modes_spec.lua` | The overlay driven by its own keymaps: grid motion, hotkeys, the `/` filter, list mode, `entries()` limits and the two "nothing to show" paths. |
| `api_spec.lua` | The public Lua API: idempotent `setup()`, delegation, `cascade_groups()`, the three `checkbox_target()` branches — one of which is a pinned bug. |
| `bindings_spec.lua` | usrcmds/keymaps/autocmds: declaring vs. binding, per-action overrides, each declared `rhs`, and `bindings.setup()` as a whole. |
| `health_spec.lua` | `:checkhealth emojis` against a `vim.health` recorder, with every optional dependency driven from both sides. |

## Coverage

Every module under `lua/emojis/` has assertion-backed coverage. Deliberately
left out, with the reason:

- **`lua/emojis/@types.lua`** — `---@class`/`---@alias` annotations only, no
  runtime code.
- **`lua/emojis/config/DEFAULTS.lua`** — a declarative table. Its *shape* is
  asserted (`config_spec.lua`: every pick's glyph decodes to a `names` entry
  with a matching label, and no two glyphs collide on one codepoint), but not
  each of its ~60 entries individually.
- **`plugin/emojis.lua` and `plugin/emojis_autodoc.lua`** — a three-line
  `vim.g.loaded_emojis` guard, and a one-shot `helptags` generator that runs at
  startup (the suite starts with `-u NONE`, so neither is even sourced).
- **The real picker backends** — telescope.nvim and fzf-lua are optional and
  are not checked out in CI; `picker_engine_spec.lua` covers everything the
  plugin hands them and everything it does with what they hand back, but not
  their own rendering.
- **The real `rg` process** — every branch around it is covered from recorded
  stdout, including the chunk boundaries neither transport protects against;
  actually running ripgrep would test ripgrep.
- **`overlay`'s float geometry** — the window is really opened and its rendered
  lines are asserted; its theming/border is `ui.kit`'s surface, which has its
  own suite in ui.nvim.

## Pinned bugs

Four defects are pinned with `BUG:`-marked assertions, so the suite fails the
day the behaviour changes and the note explains what "fixed" would look like:

1. **`emojis/init.lua`, the visual branch** (`api_spec.lua`) —
   `checkbox_target()` reads the `'<`/`'>` marks, which Neovim only sets when
   the Visual area is *left*. The preset binds `toggle` in visual mode
   (`mode = { "n", "x" }`), so the mapping runs before that: on a first
   selection it refuses ("no previous visual selection"), and afterwards it
   silently toggles the lines of the *previous* selection. `:'<,'>Emojis
   toggle` is unaffected — it arrives as an explicit Vim range.
2. **`overlay/frecency.lua`, `save()`** (`frecency_spec.lua`) —
   `vim.fn.mkdir(parent, "p")` is called outside any pcall, so a parent that
   cannot be created (classically: it already exists as a file) raises a raw
   `E739` out of `record()` and therefore out of every emoji insertion. The
   module's own doc rules that out: "losing a usage histogram must never break
   emoji insertion".
3. **`search.lua`, the `file:line:text` split** (`search_run_spec.lua`) — the
   greedy `^(.+):%d+:` lets a `:<digits>:` token inside the *matched text* win
   over the real separator. This plugin's own shortcode vocabulary contains one
   (`:100:` for 💯), so such a line is attributed to a non-existent file and to
   the wrong line number; for `clear`/`replace` that parse then feeds
   `fn.readfile`, which raises `E484` on the invented path.
4. **`search.lua`, `RG_PATTERN`** (`search_run_spec.lua`) — the ripgrep pattern
   covers three of the four codepoint ranges the in-buffer tokenizer matches;
   Misc Technical (U+2300-23FF: ⌚ ⏳ ⏰ …) is missing, so `cwd`-scoped actions
   silently skip glyphs every buffer-scoped action finds. Already documented as
   a CDX note in `search.lua`.

A fifth, smaller one is pinned in `health_spec.lua`: `health.check()` reports a
missing `lib.nvim` composer as an error and then calls
`composer.checkhealth()` unconditionally, so on the machine that needs that
message most the report raises right after emitting it.

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.scratch` / `H.notices`) and add its filename to the `specs` list in
`run.lua`.

Two house rules the existing specs follow:

- **Assert the result, not the absence of an error.** For anything that touches
  a buffer, that means the exact resulting line — emoji are multi-byte, and a
  byte-vs-character mistake produces a wrong line, not a crash.
- **Leave the world as you found it.** A spec that calls `config.setup(...)`
  ends with `config.setup({})`; one that replaces a function or a
  `package.loaded` entry restores it, including on failure.
