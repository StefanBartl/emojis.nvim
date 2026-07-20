# Configuration

Full defaults:

```lua
require("emojis").setup({
  default_scope = "%",        -- scope used when none is given
  command       = "Emojis",   -- name of the user command

  -- Entries for the insert picker: { glyph, label }. Both `picks` and
  -- `names` are derived internally from the same catalog (60+ entries) — one
  -- label feeds both the picker and the replace/unreplace map.
  picks = {
    { "✅", "white_check_mark" }, { "❌", "x" }, { "⚠️", "warning" }, --[[ … ]]
  },

  -- Codepoint -> :name: for replace/unreplace (derived from `picks`)
  names = {
    [0x2705] = ":white_check_mark:",
    [0x26A0] = ":warning:",
    -- …
  },

  -- cwd search (ripgrep)
  search = {
    cmd = "rg",
    extra_args = { "--no-heading", "--line-number", "--with-filename", "--color=never" },
    no_ignore = false,  -- true -> --no-ignore (also searches gitignored files)
  },

  -- Opt-in preset keymaps (see "Recommended Keymaps" in docs/keymaps.md)
  keymaps = {
    preset = false,
  },

  -- Marker for the `wrap` action
  wrap = {
    prefix = "[[",
    suffix = "]]",
  },

  -- Opt-in: briefly highlight emojis before clear/replace
  preview = {
    enable = false,
    duration_ms = 150,
    hl_group = "IncSearch",
  },

  -- Insert picker engine: "auto" | "telescope" | "fzf-lua" | "select"
  picker = {
    engine = "auto",
  },

  -- Quick-insert overlay (`:Emojis overlay`)
  overlay = {
    mode = "grid",     -- "grid" | "grid_keys" | "list"
    frecency = true,   -- reorder `picks` by recorded usage
    columns = 5,
    limit = 20,
    title = " Emojis ",
    theme = "rounded", -- any lib.nvim.ui.kit theme arg
    -- picks = { { "✅", "white_check_mark" }, … }  -- see below
  },

  -- Emoji checkbox cycles (`:Emojis toggle [set]`)
  checkbox = {
    default_set = "",   -- "" = search every set below; or e.g. "status"
    sets = {
      checkbox = { "🔲", "✅" },
      status   = { "🔴", "🟡", "🟢" },
      review   = { "👍", "👎" },
    },
    order = { "checkbox", "status", "review" },  -- search order when default_set = ""
  },
})
```

All fields are optional and are merged with the defaults.

## Overlay

The overlay shows a small, curated set — the point is that everything is
reachable at a glance, which stops being true much past 20 cells. Use `insert`
when you need the full catalog.

`overlay.picks` takes the same `{ glyph, label }` entries as `picks`, and its
order is the starting order:

```lua
require("emojis").setup({
  overlay = {
    picks = {
      { "✅", "white_check_mark" },
      { "❌", "x" },
      { "🐛", "bug" },
    },
  },
})
```

Unlike most options, `overlay.picks` **replaces** the default list rather than
merging into it, so the example above yields exactly three cells.

With `frecency = true` (the default), every insertion — from the overlay and
from the `insert` picker alike — is counted, and the entries are re-sorted
most-used-first with a 30-day recency half-life. Ties keep your configured
order, so the grid stays stable instead of shuffling under the cursor. Sorting
never adds or removes entries: you always see exactly the glyphs you pinned.

Usage is stored as JSON under `stdpath("data")/emojis.nvim/frecency.json`. Set
`frecency = false` to disable both the reordering and the file write, or clear
the history at any time with:

```lua
require("emojis.overlay.frecency").reset()
```

The overlay is drawn with [`lib.nvim`](https://github.com/StefanBartl/lib.nvim)'s
`ui.kit`, so `theme` accepts any kit theme argument — a preset name
(`"minimal"`, `"rounded"`, `"solid"`, `"double"`, `"ascii"`) or an override
table.

## Checkboxes

`config.checkbox.sets` is a table of named glyph cycles; `:Emojis toggle
[set]` advances the glyph found on the line one step through the named set
(or, with no `set` argument, through `default_set`). Order matters twice:
within a set it is the cycle order (`toggle` wraps from the last state back
to the first), and across sets — when searching all of them — it is the
tie-break for a glyph that happens to appear in more than one.

```lua
require("emojis").setup({
  checkbox = {
    sets = {
      checkbox = { "🔲", "✅", "❌" },  -- override: now 3 states instead of 2
    },
  },
})
```

Like `overlay.picks`, a set you redefine **replaces** the default's states
rather than merging into it — `{ "🔲", "✅", "❌" }` yields exactly three
states, not the default two merged with your three. The defaults
(`checkbox`, `status`, `review`) are deliberately **disjoint** — no glyph
appears in two of them — so `default_set = ""` ("search every set") stays
unambiguous. An overlapping alternative such as the 3-state example above is
meant to *replace* `checkbox` in your own config, not sit beside it.

`order` controls which sets are searched, and in what sequence, when
`default_set = ""`; sets you add but don't list in `order` are still
searched, appended in name-sorted order, so a new set is never silently
unreachable.

`toggle` only ever *cycles* an existing glyph — see `require("emojis").toggle()`
/ `.checkbox_add()` / `.checkbox_remove()` in [`docs/api.md`](api.md) for
adding or stripping a checkbox from a line that doesn't have one yet.

### cascade.nvim bridge

If you also use [cascade.nvim](https://github.com/StefanBartl/cascade.nvim),
`require("emojis").cascade_groups()` returns `config.checkbox.sets` in
cascade's `cycle.groups` format, so the same glyphs drive both plugins
without listing them twice:

```lua
require("cascade").setup({
  cycle = { groups = require("emojis").cascade_groups() },
})
```

The two are complementary, not overlapping: cascade's `<C-y>` cycles the
glyph the cursor is *on* (cursor-precise); `:Emojis toggle` / `<leader>et`
cycles whichever configured glyph is *anywhere on the line* (line-scoped),
so it works with the cursor left at the end of the text. `cascade_groups()`
is a pure data function — it never `require("cascade")` itself, so it's safe
to call whether or not cascade.nvim is installed.
