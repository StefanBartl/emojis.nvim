# emojis.nvim — Roadmap

## Implemented (v0.2)

### Core (v0.1)

- `:Emojis [action] [scope]` — clear / replace / list / count / insert
- Scopes: `%`, `line`, `word`, `visual`, `cwd` (async ripgrep)
- Vim range overrides the scope keyword
- **Space-collapse on clear** — ` 🚀 ` → ` ` (single space), incl. emoji runs
- **VS16 grapheme handling** — ⚠️ counted once, replaced as one placeholder
- Configurable picks, name map, command name, ripgrep invocation
- Context-aware tab completion
- Pure, testable core (`patterns`, `ops`) separated from API/UI
- `config/DEFAULTS.lua` config system, idempotent `setup()`
- `:checkhealth emojis`
- No hard lib.nvim dependency (optional soft bridge for notify/map)
- `bindings/` module (usrcmds/keymaps/autocmds) with opt-in preset keymaps
  (`keymaps.preset`) and which-key group label
- `docs/BINDINGS.md` cheatsheet, `docs/TESTS/` headless spec suite

### Emoji coverage (v0.2)

- **Table-driven Unicode ranges** — `core/patterns.lua` `RANGES` +
  `range_pattern()` replace the three hand-derived byte patterns, adding
  U+2300–23FF (Misc Technical: ⌚⏰⏳). The 1F000–1FFFF band already covers
  Enclosed Alphanumeric Supplement (incl. Regional Indicator flag letters)
  and Dingbats in full.
- **ZWJ sequences, skin-tone modifiers, flag pairs** — Zero-Width-Joiner
  (U+200D) chains (👨‍👩‍👧), Fitzpatrick modifiers (U+1F3FB–1F3FF, 👍🏽), and
  paired Regional Indicator flags (🇩🇪) are each treated as one grapheme
  across `count`/`clear`/`list`/`replace`.

### Actions (v0.2)

- **`:Emojis unreplace`** — inverse of `replace`: restores `:name:`/
  `:U+XXXX:` placeholders back to emoji (`core/ops.lua` `unreplace()`,
  inverse map from `config.names`). Unrecognized `:...:` tokens are left
  untouched.
- **`:Emojis first` / `:Emojis next`** — cursor navigation to the
  first/next emoji in the buffer (`lua/emojis/nav.lua`); `next` wraps to the
  top.
- **`:Emojis wrap`** — surrounds each emoji with `config.wrap.prefix`/
  `suffix` (default `[[`/`]]`) without removing it (`core/ops.lua` `wrap()`,
  shares `map_spans()` with `replace()`).

### Scope / search (v0.2)

- **Real `word` scope** — resolves to the whitespace-delimited byte run
  under the cursor (`core/scope.lua`), not the whole line. `Emojis.Target`
  carries an optional `c1`/`c2` byte window that `actions.lua` respects for
  clear/replace/list/count.
- **`cwd` scope for `clear`/`replace`** — `search.lua` `apply_across_files()`
  asks for confirmation before mutating any file (default: cancel);
  `:Emojis list cwd` is the recommended dry-run preview. Buffers with
  unsaved changes are skipped rather than clobbered.
- **Glob/filetype filter for `cwd`** — arguments after the `cwd` keyword
  (e.g. `:Emojis count cwd *.md`) are passed to ripgrep as `--glob`
  (`search.build_cmd()`).
- **Configurable gitignore respect** — `config.search.no_ignore = true`
  appends `--no-ignore`.

### UX / integration (v0.2)

- **Telescope/fzf-lua picker** — `config.picker.engine` (default `"auto"`)
  tries telescope.nvim, then fzf-lua (both optional soft dependencies,
  `picker.lua` `try_telescope()`/`try_fzf_lua()`), falling back to
  `vim.ui.select`.
- **Larger default emoji catalog with names** — `config/DEFAULTS.lua`
  derives both `picks` (insert picker) and `names` (`replace`/`unreplace`)
  from one 60+-entry `CATALOG`; the `names` codepoint is decoded from the
  glyph itself (`patterns.codepoint`), not hand-typed.
- **Highlight preview** — `config.preview.enable = true` (default `false`)
  briefly highlights the affected emojis before `clear`/`replace` mutates
  the buffer (extmarks, `preview.hl_group`, `preview.duration_ms`,
  `actions.lua` `preview_spans()`).

## Implemented (v0.3)

### Quick-insert overlay

- **`:Emojis overlay [grid|grid_keys|list]`** / `<leader>ee` — a small float
  holding a curated, developer-shaped set of emojis (`config.overlay.picks`),
  drawn with `lib.nvim`'s `ui.kit` (`lua/emojis/overlay/`). Three interaction
  modes: `grid` (hjkl/arrows + `<CR>`, default), `grid_keys` (one hotkey per
  cell), `list` (delegates to `kit.select`).
- **Frecency ordering** — every insertion, from the overlay *and* the
  `insert` picker (`core/insert.lua` shared helper), is recorded to
  `stdpath("data")/emojis.nvim/frecency.json` and reorders `overlay.picks`
  (most-used-first, 30-day recency half-life). Sorting only ever reorders the
  configured set; it never adds or removes entries. `overlay.frecency = false`
  disables both the reordering and the file write.

### Emoji checkboxes

- **`:Emojis toggle [set]`** / `<leader>et` (normal + visual, range-aware) —
  cycles an emoji "checkbox" glyph found anywhere on the line (`core/checkbox.lua`),
  e.g. `🔲 1. Hallo` → `✅ 1. Hallo`. Line-scoped rather than cursor-scoped, so
  the cursor can sit anywhere on the line.
- **Configurable cycle sets** — `config.checkbox.sets` (default: disjoint
  `checkbox`, `status`, `review` cycles), `checkbox.order` for ambiguity
  resolution when searching every set, `checkbox.default_set` to pin one.
- **cascade.nvim bridge** — `require("emojis").cascade_groups()` returns the
  configured sets in cascade's `cycle.groups` format, so the same glyph
  vocabulary drives both cascade's cursor-precise `<C-y>` cycling and
  emojis.nvim's line-scoped `:Emojis toggle` — no glyph list duplicated
  between the two plugins.

---

## Nicht geplant

- **Emoji-Rendering / Font-Handling** — Sache des Terminals/GUI, nicht des Plugins.
- **Eigene Unicode-Datenbank als Abhängigkeit** — die kompakten Byte-Ranges
  decken den praktischen Bedarf ab; eine vollständige UCD wäre überdimensioniert.
- **Autocmd-getriebenes Auto-Clear beim Speichern** — zu invasiv; bewusst ein
  explizit aufgerufener Befehl (siehe Leitlinie „Event oder Command?").
