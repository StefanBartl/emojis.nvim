-- TESTS/patterns_spec.lua — tokenizer: base emoji matching, VS16, spans.

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

  -- a regional indicator followed by a non-flag emoji does not pair with it
  do
    local mixed = "🇩🚀"
    eq(patterns.count(mixed), 2, "count: a regional indicator only pairs with another one")
    local sp = patterns.spans(mixed)
    eq(sp[1][2], 4, "spans: the lone indicator ends after its own 4 bytes")
  end

  -- skin tone never applies to a regional indicator, so the bytes after one
  -- stay a grapheme of their own
  do
    eq(patterns.count("🇩🏽"), 2, "count: a skin-tone modifier after a flag letter is not absorbed")
  end

  -- skin tone + VS16 on the same base is still one grapheme
  do
    local combined = "👍🏽" .. patterns.VS16
    eq(patterns.count(combined), 1, "count: skin tone followed by VS16 is one grapheme")
    eq(patterns.spans(combined)[1][2], #combined, "spans: ... spanning every byte")
  end

  -- a dangling ZWJ (nothing joinable after it) ends the chain instead of
  -- swallowing the rest of the line
  do
    local ZWJ = "\226\128\141"
    local dangling = "👨" .. ZWJ .. "x"
    eq(patterns.count(dangling), 1, "count: a dangling ZWJ does not extend the grapheme")
    eq(patterns.spans(dangling)[1][2], #"👨", "spans: ... the span ends at the base emoji")
  end

  -- match_at is anchored: it answers for exactly the byte it is given
  do
    local s = "ab🚀"
    eq(patterns.match_at(s, 1), nil, "match_at: nil where no emoji starts")
    eq(patterns.match_at(s, 3), #s, "match_at: the end byte where one does")
    eq(patterns.match_at(s, 4), nil, "match_at: nil in the middle of a grapheme")
  end

  -- encode is the inverse of codepoint, across all four UTF-8 lengths (the
  -- 1/2-byte cases are what `unreplace` rebuilds from a `:U+XX:` token)
  do
    eq(patterns.encode(0x41), "A", "encode: 1-byte codepoint")
    eq(patterns.encode(0xA9), "©", "encode: 2-byte codepoint")
    eq(patterns.encode(0x26A0), "⚠", "encode: 3-byte codepoint")
    eq(patterns.encode(0x1F680), "🚀", "encode: 4-byte codepoint")
    eq(patterns.codepoint(patterns.encode(0x1F525)), 0x1F525, "encode/codepoint: round-trip")
  end

  -- codepoint decodes the FIRST component only, whatever follows it
  do
    eq(patterns.codepoint("🇩🇪"), 0x1F1E9, "codepoint: a flag decodes to its first letter")
    eq(patterns.codepoint("👨‍👩‍👧"), 0x1F468, "codepoint: a ZWJ chain decodes to its base")
    eq(patterns.codepoint("👍🏽"), 0x1F44D, "codepoint: a skin tone does not change the base")
  end

  -- an empty string and pure text are the degenerate cases
  do
    eq(patterns.count(""), 0, "count: empty string")
    eq(#patterns.spans(""), 0, "spans: empty string")
    eq(#patterns.spans("plain ascii"), 0, "spans: no emoji, no spans")
  end
end
