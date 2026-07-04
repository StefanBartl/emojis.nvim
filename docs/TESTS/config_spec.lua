-- docs/TESTS/config_spec.lua — DEFAULTS catalog: picks/names stay in sync.

return function(H)
  local eq = H.eq
  local ok = H.ok
  local patterns = require("emojis.core.patterns")
  local DEFAULTS = require("emojis.config.DEFAULTS")

  ok(#DEFAULTS.picks >= 50, "catalog: at least 50 entries")

  -- every pick's glyph decodes to a names entry with the matching label,
  -- and no two glyphs collide on the same codepoint (which would silently
  -- drop an entry from `names`).
  local seen = {}
  for i = 1, #DEFAULTS.picks do
    local glyph, label = DEFAULTS.picks[i][1], DEFAULTS.picks[i][2]
    local cp = patterns.codepoint(glyph)
    ok(not seen[cp], ("catalog: no codepoint collision for %s (%s)"):format(glyph, label))
    seen[cp] = true
    eq(DEFAULTS.names[cp], ":" .. label .. ":", ("catalog: names[cp] matches picks label for %s"):format(glyph))
  end

  local names_count = 0
  for _ in pairs(DEFAULTS.names) do
    names_count = names_count + 1
  end
  eq(names_count, #DEFAULTS.picks, "catalog: names has exactly one entry per pick")
end
