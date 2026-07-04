-- docs/TESTS/patterns_spec.lua — tokenizer: base emoji matching, VS16, spans.

return function(H)
  local eq = H.eq
  local patterns = require("emojis.core.patterns")

  -- count: plain 4-byte emoji
  eq(patterns.count("a 🚀 b"), 1, "count: single 4-byte emoji")
  eq(patterns.count("no emoji here"), 0, "count: no emoji")

  -- VS16-decorated emoji counts as exactly one grapheme
  eq(patterns.count("⚠️"), 1, "count: VS16 emoji counted once")
  eq(patterns.count("a ⚠️ b 🔥 c"), 2, "count: mixed VS16 + 4-byte")

  -- spans: end byte includes a trailing VS16
  local spans = patterns.spans("⚠️x")
  eq(#spans, 1, "spans: one span for VS16 emoji")
  local warning = "⚠️"
  eq(spans[1][1], 1, "spans: start byte")
  eq(spans[1][2], #warning, "spans: end byte includes VS16")

  -- codepoint: decodes the base emoji, ignoring a trailing VS16
  eq(patterns.codepoint("⚠️"), 0x26A0, "codepoint: warning sign")
  eq(patterns.codepoint("🚀"), 0x1F680, "codepoint: rocket")
end
