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
}

return DEFAULTS
