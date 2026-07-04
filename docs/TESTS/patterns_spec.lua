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

  -- Misc Technical block (watch/hourglass/media symbols)
  eq(patterns.count("⌚"), 1, "count: watch (Misc Technical)")

  -- skin-tone modifier: attaches to the preceding base as one grapheme
  do
    local thumbs_up_medium = "👍🏽"
    eq(patterns.count(thumbs_up_medium), 1, "count: base + skin-tone is one grapheme")
    local sp = patterns.spans(thumbs_up_medium)
    eq(#sp, 1, "spans: one span for base + skin-tone")
    eq(sp[1][2], #thumbs_up_medium, "spans: end byte includes skin-tone modifier")
  end

  -- ZWJ chain: family emoji (man + ZWJ + woman + ZWJ + girl) is one grapheme
  do
    local family = "👨‍👩‍👧"
    eq(patterns.count(family), 1, "count: ZWJ family sequence is one grapheme")
  end

  -- regional indicator flag pairing: two adjacent RI letters -> one grapheme
  do
    local flag = "🇩🇪" -- Germany: REGIONAL INDICATOR D + E
    eq(patterns.count(flag), 1, "count: paired regional indicators form one flag")
  end

  -- a lone regional indicator (no partner) stays a single-letter grapheme
  do
    local lone = "🇩x"
    eq(patterns.count(lone), 1, "count: unpaired regional indicator is still one grapheme")
  end
end
