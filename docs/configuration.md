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
})
```

All fields are optional and are merged with the defaults.
