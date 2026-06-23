---@module 'emojis.config.DEFAULTS'
---@brief Immutable default configuration for emojis.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a
--- copy of this table, so it is never mutated at runtime.

---@type Emojis.Config
local DEFAULTS = {
  default_scope = "%",
  command       = "Emojis",

  -- Insert-picker entries: { glyph, label }
  picks = {
    { "✅", "check" },   { "❌", "cross" },   { "⚠️", "warning" }, { "💡", "bulb" },
    { "📝", "memo" },    { "🔥", "fire" },    { "🚀", "rocket" },  { "🐛", "bug" },
    { "🔧", "wrench" },  { "🔴", "red" },     { "🟡", "yellow" },  { "🟢", "green" },
    { "📌", "pin" },     { "📎", "clip" },    { "🏁", "flag" },    { "💬", "speech" },
    { "🤔", "think" },   { "👍", "up" },      { "👎", "down" },    { "🎯", "dart" },
    { "🔒", "lock" },    { "🔓", "unlock" },  { "⭐", "star" },     { "💯", "100" },
    { "✨", "sparkle" }, { "💥", "boom" },    { "🛑", "stop" },    { "🆕", "new" },
  },

  -- Codepoint -> :name: used by the `replace` action.
  names = {
    [0x2705] = ":white_check_mark:", [0x274C] = ":x:",
    [0x2B50] = ":star:",             [0x26A0] = ":warning:",
    [0x1F600] = ":grinning:",        [0x1F602] = ":joy:",
    [0x1F525] = ":fire:",            [0x1F680] = ":rocket:",
    [0x1F4A1] = ":bulb:",            [0x1F4DD] = ":memo:",
    [0x1F41B] = ":bug:",             [0x1F527] = ":wrench:",
    [0x1F512] = ":lock:",            [0x1F3AF] = ":dart:",
    [0x1F3C1] = ":checkered_flag:",  [0x1F534] = ":red_circle:",
    [0x1F7E2] = ":green_circle:",    [0x1F7E1] = ":yellow_circle:",
    [0x1F44D] = ":thumbsup:",        [0x1F44E] = ":thumbsdown:",
  },

  search = {
    cmd = "rg",
    extra_args = {
      "--no-heading", "--line-number", "--with-filename", "--color=never",
    },
  },
}

return DEFAULTS
