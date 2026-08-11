# Workflow — getting real use out of emojis.nvim day to day

Every feature here is documented on its own elsewhere (`docs/commands.md`,
`docs/configuration.md`, `docs/api.md`). This is the different question:
which action/scope combinations actually get reached for daily, and what
trips people up when they don't.

## `insert` vs. `overlay` — full catalog vs. muscle memory

Two different pickers exist for a reason, and reaching for the wrong one
under time pressure costs a few seconds each time it happens:

- **`:Emojis insert`** (`<C-e>`) fuzzy-searches the **full** catalog
  (60+ entries). Use it when you know roughly what you want but not which
  key opens it fastest — "warning", "bug", whatever the name is.
- **`:Emojis overlay`** (`<leader>ee`) opens a small float with ~20
  curated glyphs, meant to be opened and dismissed in a second or two.
  Use it for the handful of emojis you reach for constantly — commit
  markers, status glyphs — where searching by name is slower than
  glancing at a fixed grid.

`grid_keys` mode is the fastest overlay variant once you've memorized the
layout: one keypress inserts, no `<CR>` needed. Switch to it
(`overlay.mode = "grid_keys"`) only after the grid's layout has become
familiar — it trades discoverability (no visible cue which key does what
beyond the grid position) for raw speed.

Frecency reordering (`overlay.frecency`, on by default) means the grid's
layout *will* drift over the first few weeks of use to match your actual
habits — don't fight it by re-pinning `overlay.picks` every time it moves
a glyph; let it settle, and only override `overlay.picks` for glyphs you
want present regardless of usage.

## `list cwd` before `clear cwd`/`replace cwd` — always, not just "recommended"

This is the one action pair where skipping the dry run has real
consequences: `clear cwd`/`replace cwd` touch every matching file in the
project, not just the open buffer, and only ask for confirmation once
(default answer: cancel). The actual habit worth building:

```vim
:Emojis list cwd          " see exactly what would be touched
:Emojis clear cwd         " now apply, informed
```

`list cwd *.md` first if you only care about one file type — the same
`--glob` filter arguments work on `list` as on `clear`/`replace`, so
narrowing at the dry-run stage and the apply stage should always match;
running `list cwd` unfiltered and then `clear cwd *.md` filtered is an
easy way to convince yourself you checked something you didn't.

**The gotcha this exists to prevent:** a buffer already open with unsaved
changes is *skipped*, not overwritten, during a `cwd` clear/replace — the
summary reports it as "skipped". That's a safety feature, not a bug, but
it means a `clear cwd` run right after editing a file (before saving)
silently leaves that one file's emojis untouched while cleaning
everything else. Save first, or re-run `clear cwd` after saving, if the
open-but-unsaved file actually needs the pass too.

## `toggle` — line-scoped by design, not a limitation

`:Emojis toggle` deliberately has no `%`/`word`/`cwd` scope — only a line
range. This is easy to misread as a missing feature; it's the opposite.
Given a file full of checkbox lines, the natural reflex is "toggle
everything at once", but `toggle` cycling every checkbox in a buffer
would be indistinguishable from noise — most files have some boxes
checked and some not, and a blanket toggle would flip both directions at
once. What actually works for "toggle several lines" is a Vim range:

```vim
:5,12Emojis toggle status   " cycle the "status" set on lines 5-12
:'<,'>Emojis toggle         " cycle every configured set on the visual block
```

Naming the set (`status`, `checkbox`, `review`) instead of leaving it
blank matters more here than on a single line — with no `set` argument,
`toggle` searches through `checkbox.order` and advances the *first*
matching set's glyph on each line, which across a multi-line range can
mean different lines get cycled through different sets if their glyphs
overlap (they shouldn't, if you kept the defaults disjoint, but a custom
overlapping set changes that).

## Checkbox sets: keep them disjoint, or `default_set = ""` gets ambiguous

The shipped defaults (`checkbox`, `status`, `review`) share no glyph
across sets on purpose — `toggle` with no `set` argument can search all
of them unambiguously. The moment a custom set reuses a glyph from
another set (the docs' own 3-state `checkbox` example,
`{ "🔲", "✅", "❌" }`, overlaps with the default two-state `checkbox`), it's
meant to *replace* that entry, not sit next to it — defining both without
removing the original creates exactly the ambiguity the disjoint-by-
default design avoids. If a project genuinely needs overlapping cycles,
always call `toggle` with an explicit `set` name for those lines rather
than relying on the search order to guess right.

## `cascade_groups()` — one vocabulary, two cycling styles

If [cascade.nvim](https://github.com/StefanBartl/cascade.nvim) is also
installed, wiring `require("emojis").cascade_groups()` into its
`cycle.groups` means the same checkbox glyphs work two ways without
double-listing them: `<leader>et` cycles the glyph anywhere on the
**line** (useful when the cursor is at the end of typed text, not on the
glyph itself); cascade's `<C-y>` cycles the glyph the cursor is precisely
**on** (useful mid-line, e.g. adjusting a status glyph embedded in a
longer line without moving the cursor first). Reach for cascade's binding
when precision matters more than convenience, `<leader>et` otherwise —
they read from the same `checkbox.sets` table, so there's no drift
between what each cycles through.

## The double-space fix changes what `clear`'s output actually looks like

Worth knowing before writing a script or test that asserts on `clear`'s
exact output: `" 🚀 "` becomes `" "` (one space), not `"  "` (two) —
`clear` collapses the space on both sides of a removed emoji or emoji run
down to one, rather than leaving the old double-space artifact behind.
`ops.clear()` (the pure, buffer-free variant used in scripts/tests via
`require("emojis").ops()`) has the identical behavior, so a unit test
checking `ops.clear({ " 🚀 done" })` should expect `{ " done" }`, not
`{ "  done" }`.

## `preview.enable` — worth turning on once, not by default

`preview.enable = true` briefly highlights (150ms default) what a
`clear`/`replace` is about to touch before it happens. It's off by
default because most `clear`/`replace` calls are on a scope you already
know the contents of (the current line, a visual selection); the value
shows up specifically on wider scopes (`%`, and especially before you've
built confidence in `cwd`) where seeing the highlight land somewhere
unexpected is a cheap last check before the buffer actually changes.
Turning it on permanently costs nothing but a 150ms flash on every clear/
replace — worth it if you use `%`/`cwd` scopes often, skippable if you
mostly work on `line`/`word`/`visual` where the scope is already visible
on screen.
