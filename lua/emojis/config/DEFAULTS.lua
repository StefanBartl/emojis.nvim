---@module 'emojis.config.DEFAULTS'
---@brief Immutable default configuration for emojis.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a
--- copy of this table, so it is never mutated at runtime.
---
--- `picks` (the insert-picker entries) and `names` (the replace/unreplace
--- shortcode map) are both derived from one `CATALOG` list below, so a single
--- glyph/label pair feeds both features. The codepoint used as the `names`
--- key is decoded from the glyph itself (`patterns.codepoint`) rather than
--- hand-typed, so a typo'd hex value can't silently desync from the glyph.

local patterns = require("emojis.core.patterns")

---@type {[1]: string, [2]: string}[]  { glyph, shortcode label (without colons) }
local CATALOG = {
  { "✅", "white_check_mark" },
  { "❌", "x" },
  { "⚠️", "warning" },
  { "💡", "bulb" },
  { "📝", "memo" },
  { "🔥", "fire" },
  { "🚀", "rocket" },
  { "🐛", "bug" },
  { "🔧", "wrench" },
  { "🔴", "red_circle" },
  { "🟡", "yellow_circle" },
  { "🟢", "green_circle" },
  { "📌", "pushpin" },
  { "📎", "paperclip" },
  { "🏁", "checkered_flag" },
  { "💬", "speech_balloon" },
  { "🤔", "thinking" },
  { "👍", "thumbsup" },
  { "👎", "thumbsdown" },
  { "🎯", "dart" },
  { "🔒", "lock" },
  { "🔓", "unlock" },
  { "⭐", "star" },
  { "💯", "100" },
  { "✨", "sparkles" },
  { "💥", "boom" },
  { "🛑", "octagonal_sign" },
  { "🆕", "new" },
  { "😀", "grinning" },
  { "😂", "joy" },
  { "🎉", "tada" },
  { "❤️", "heart" },
  { "👏", "clap" },
  { "🙏", "pray" },
  { "💪", "muscle" },
  { "👋", "wave" },
  { "😢", "cry" },
  { "🙂", "slightly_smiling_face" },
  { "😅", "sweat_smile" },
  { "😎", "sunglasses" },
  { "😴", "sleeping" },
  { "🥳", "partying_face" },
  { "🤝", "handshake" },
  { "👀", "eyes" },
  { "💤", "zzz" },
  { "✔️", "heavy_check_mark" },
  { "❗", "exclamation" },
  { "❓", "question" },
  { "🚫", "no_entry_sign" },
  { "⚙️", "gear" },
  { "📈", "chart_with_upwards_trend" },
  { "📉", "chart_with_downwards_trend" },
  { "📁", "file_folder" },
  { "🏆", "trophy" },
  { "🌟", "star2" },
  { "☀️", "sunny" },
  { "🌙", "crescent_moon" },
  { "🍕", "pizza" },
  { "☕", "coffee" },
  { "🎁", "gift" },
}

---@type Emojis.Config.PickEntry[], table<integer, string>
local picks, names = {}, {}
for i = 1, #CATALOG do
  local glyph, label = CATALOG[i][1], CATALOG[i][2]
  picks[i] = { glyph, label }
  names[patterns.codepoint(glyph)] = ":" .. label .. ":"
end

---@type string[]  Curated quick-insert set for the overlay, in starting order.
--- Deliberately short and developer-shaped (status, review, diagnostics) rather
--- than a slice of CATALOG: the overlay's value is that everything is reachable
--- in one glance, which stops being true past ~20 cells. Frecency reorders this
--- list at runtime; it never grows it.
local OVERLAY_LABELS = {
  "white_check_mark",
  "x",
  "warning",
  "bug",
  "fire",
  "rocket",
  "bulb",
  "memo",
  "wrench",
  "gear",
  "pushpin",
  "dart",
  "lock",
  "question",
  "exclamation",
  "eyes",
  "thumbsup",
  "sparkles",
  "boom",
  "tada",
}

---@type table<string, string>  label -> glyph, for the overlay lookup below.
local by_label = {}
for i = 1, #CATALOG do
  by_label[CATALOG[i][2]] = CATALOG[i][1]
end

---@type Emojis.Config.PickEntry[]
local overlay_picks = {}
for i = 1, #OVERLAY_LABELS do
  local label = OVERLAY_LABELS[i]
  local glyph = by_label[label]
  if glyph then
    overlay_picks[#overlay_picks + 1] = { glyph, label }
  end
end

---@type Emojis.Config
local DEFAULTS = {
  default_scope = "%",
  command = "Emojis",

  -- Insert-picker entries: { glyph, label }. Derived from CATALOG above.
  picks = picks,

  -- Codepoint -> :name: used by the `replace`/`unreplace` actions. Derived
  -- from CATALOG above.
  names = names,

  search = {
    cmd = "rg",
    extra_args = {
      "--no-heading",
      "--line-number",
      "--with-filename",
      "--color=never",
    },
    -- When true, pass --no-ignore so rg also searches gitignored files.
    no_ignore = false,
  },

  -- Opt-in preset keymaps: <C-e> insert, <leader>ec count %, <leader>el list %.
  keymaps = {
    preset = false,
  },

  -- Marker used by the `wrap` action to surround (not remove) each emoji.
  wrap = {
    prefix = "[[",
    suffix = "]]",
  },

  -- Opt-in: briefly highlight affected emojis before `clear`/`replace` mutate
  -- the buffer.
  preview = {
    enable = false,
    duration_ms = 150,
    hl_group = "IncSearch",
  },

  -- Insert-picker engine: "auto" tries telescope.nvim then fzf-lua (both
  -- optional), falling back to vim.ui.select.
  picker = {
    engine = "auto",
  },

  -- Emoji checkbox cycles (`:Emojis toggle [set]`).
  --
  -- Order matters twice over: within a set it is the cycle order, and across
  -- sets it breaks ambiguity — a glyph appearing in two sets belongs to the
  -- one listed first. `default_set` picks which cycle `:Emojis toggle` uses
  -- with no argument; "" (the empty string) means "search every set", which is
  -- what makes a single keymap work across mixed checkbox styles in one file.
  -- The default sets are deliberately *disjoint*: no glyph appears in two of
  -- them, so "search every set" is unambiguous and every set stays reachable.
  -- Overlapping alternatives (e.g. a 3-state `{ "🔲", "✅", "❌" }`) are meant
  -- to *replace* `checkbox` rather than sit beside it — see
  -- docs/configuration.md#checkboxes.
  checkbox = {
    default_set = "",
    sets = {
      checkbox = { "🔲", "✅" },
      status = { "🔴", "🟡", "🟢" },
      review = { "👍", "👎" },
    },
    -- Order in which sets are searched when no `default_set` is configured.
    -- Sets missing from this list are appended in a stable (name-sorted) order,
    -- so adding a set never silently disables it.
    order = { "checkbox", "status", "review" },
  },

  -- Quick-insert overlay (`:Emojis overlay [mode]`).
  overlay = {
    -- "grid" navigates with hjkl/arrows + <CR>; "grid_keys" adds a direct
    -- hotkey per cell; "list" is a one-per-row chooser.
    mode = "grid",
    picks = overlay_picks,
    -- Reorder `picks` by recorded usage (never adds/removes entries).
    frecency = true,
    columns = 5,
    limit = 20,
    title = " Emojis ",
    -- Any lib.nvim.ui.kit theme arg: preset name or override table.
    theme = "rounded",
  },
}

return DEFAULTS
