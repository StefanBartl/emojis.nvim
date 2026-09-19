-- TESTS/unicode_data_spec.lua — emojis.unicode.data: parsing UnicodeData.txt's
-- own format, purely in memory. No network, no filesystem — every case feeds
-- M.parse() a hand-written fixture string, the same shape a real UCD line has.

return function(H)
  local eq, ok = H.eq, H.ok
  local data = require("emojis.unicode.data")

  -- A minimal real-shaped excerpt: LATIN CAPITAL LETTER A, plus a control
  -- code whose only name is its Unicode_1_Name (field 11), plus a
  -- First/Last range pair (the CJK Unified Ideographs shape).
  local FIXTURE = table.concat({
    "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;",
    "0000;<control>;Cc;0;BN;;;;;N;NULL;;;;",
    "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;",
    "9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;",
  }, "\n")

  local parsed = data.parse(FIXTURE)

  eq(parsed.by_cp[0x0041], "LATIN CAPITAL LETTER A", "parse: ordinary row keeps its Name field")
  eq(parsed.by_cp[0x0000], "NULL", "parse: <control> falls back to Unicode_1_Name")
  eq(parsed.by_cp[0x4E00], nil, "parse: a First/Last range is not stored per-codepoint")
  eq(#parsed.ranges, 1, "parse: exactly one range recorded")
  eq(parsed.ranges[1].lo, 0x4E00, "parse: range lo")
  eq(parsed.ranges[1].hi, 0x9FFF, "parse: range hi")
  eq(parsed.ranges[1].label, "CJK Ideograph", "parse: range label")
  eq(parsed.truncated, false, "parse: a well-formed, fully-paired file is not truncated")

  -- list mirrors by_cp, in encounter order, for the two resolvable rows.
  eq(#parsed.list, 2, "parse: list has the two resolvable rows, not the range pair")

  -- name_for: exact row, synthesized range name, and "nothing at all".
  eq(data.name_for(parsed, 0x0041), "LATIN CAPITAL LETTER A", "name_for: exact row")
  eq(data.name_for(parsed, 0x4E2D), "CJK UNIFIED IDEOGRAPH-4E2D", "name_for: synthesized range name")
  eq(data.name_for(parsed, 0x10FFFF), nil, "name_for: nothing known at all -> nil")

  -- An unlabeled range (no SYNTH_PREFIX entry) still gets a usable name,
  -- just from its own uppercased label rather than the Unicode convention.
  local FIXTURE2 = table.concat({
    "F0000;<Made Up Block, First>;Co;0;L;;;;;N;;;;;",
    "F0010;<Made Up Block, Last>;Co;0;L;;;;;N;;;;;",
  }, "\n")
  local parsed2 = data.parse(FIXTURE2)
  eq(data.name_for(parsed2, 0xF0005), "MADE UP BLOCK-F0005", "name_for: unlisted label falls back to its own uppercase")

  -- truncated: a First row with no matching Last before EOF -- the shape a
  -- download cut off mid-file would leave behind.
  local DANGLING = table.concat({
    "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;",
    "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;",
  }, "\n")
  local dangling = data.parse(DANGLING)
  eq(dangling.truncated, true, "parse: an unmatched First at EOF is truncated")
  eq(#dangling.ranges, 0, "parse: the dangling First produces no range")
  eq(dangling.by_cp[0x0041], "LATIN CAPITAL LETTER A", "parse: rows before the dangling First still parse")

  -- truncated: a second First for a different block arrives before the
  -- first block's Last -- the first block silently loses its range unless
  -- flagged.
  local OVERWRITTEN = table.concat({
    "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;",
    "AC00;<Hangul Syllable, First>;Lo;0;L;;;;;N;;;;;",
    "D7A3;<Hangul Syllable, Last>;Lo;0;L;;;;;N;;;;;",
  }, "\n")
  local overwritten = data.parse(OVERWRITTEN)
  eq(overwritten.truncated, true, "parse: a First overwriting a still-open pending is truncated")
  eq(#overwritten.ranges, 1, "parse: only the properly-closed (Hangul) range survives")
  eq(overwritten.ranges[1].label, "Hangul Syllable", "parse: the surviving range is the Hangul one")
  eq(data.name_for(overwritten, 0x4E2D), nil, "name_for: the silently-dropped CJK block resolves to nothing")

  -- cached()/ensure() memoization: reset() drops the in-memory table so a
  -- later ensure() would re-read the cache file (not exercised here — this
  -- only checks reset() actually clears the module-level state contract).
  ok(type(data.cached) == "function", "cached: exported")
  ok(type(data.ensure) == "function", "ensure: exported")
  data.reset()
end
