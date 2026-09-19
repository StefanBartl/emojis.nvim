-- TESTS/ops_spec.lua — clear/count/list/replace on string arrays.

return function(H)
  local eq = H.eq
  local ops = require("emojis.core.ops")

  -- clear: space-collapse on both sides of a removed emoji (run)
  do
    local out, n = ops.clear({ " 🚀 " })
    eq(out[1], " ", "clear: both-side spaces collapse to one")
    eq(n, 1, "clear: removed count")
  end
  do
    local out, n = ops.clear({ "a 🚀 b" })
    eq(out[1], "a b", "clear: collapses surrounding spaces mid-line")
    eq(n, 1, "clear: removed count")
  end
  do
    local out, n = ops.clear({ " 🚀🔥 " })
    eq(out[1], " ", "clear: adjacent emoji run collapses as one unit")
    eq(n, 2, "clear: counts both emojis in the run")
  end
  do
    local out, n = ops.clear({ "a🚀b" })
    eq(out[1], "ab", "clear: no surrounding spaces, nothing collapsed")
    eq(n, 1, "clear: removed count")
  end

  -- count
  eq(ops.count({ "a ⚠️ b", "no emoji" }), 1, "count: across lines")

  -- list: 1-based lnum via line_offset, 0-based col
  do
    local entries = ops.list({ "a 🚀 b" }, 4) -- offset: buffer line 5
    eq(#entries, 1, "list: one entry")
    eq(entries[1].lnum, 5, "list: lnum uses the offset")
    eq(entries[1].col, 2, "list: 0-based byte column")
    eq(entries[1].text, "🚀", "list: emoji glyph text")
  end

  -- replace: known codepoint -> configured name; unknown -> :U+XXXX: fallback
  do
    local out, n = ops.replace({ "a ✅ b 🎉 c" }, { [0x2705] = ":white_check_mark:" })
    eq(out[1], "a :white_check_mark: b :U+1F389: c", "replace: known + fallback names")
    eq(n, 2, "replace: replaced count")
  end

  -- unreplace: inverse of replace, including the :U+XXXX: fallback form
  do
    local out, n = ops.unreplace({ "a :white_check_mark: b :U+1F389: c :unknown_token:" }, { [0x2705] = ":white_check_mark:" })
    eq(out[1], "a ✅ b 🎉 c :unknown_token:", "unreplace: known name + fallback restored, unknown left alone")
    eq(n, 2, "unreplace: restored count")
  end
  do
    -- round-trip: replace() then unreplace() restores the original text
    local names = { [0x2705] = ":white_check_mark:" }
    local replaced = ops.replace({ "a ✅ b 🎉 c" }, names)
    local restored, n = ops.unreplace(replaced, names)
    eq(restored[1], "a ✅ b 🎉 c", "unreplace: round-trips with replace")
    eq(n, 2, "unreplace: round-trip count")
  end

  -- wrap: surrounds each emoji without removing it
  do
    local out, n = ops.wrap({ "a ✅ b 🎉 c" }, "[[", "]]")
    eq(out[1], "a [[✅]] b [[🎉]] c", "wrap: surrounds each emoji")
    eq(n, 2, "wrap: wrapped count")
  end

  -- clear: a ZWJ family sequence / flag pair counts and clears as one grapheme
  do
    local out, n = ops.clear({ " 👨‍👩‍👧 " })
    eq(out[1], " ", "clear: ZWJ family sequence collapses like a single emoji")
    eq(n, 1, "clear: ZWJ chain counted once")
  end
  do
    local out, n = ops.clear({ " 🇩🇪 " })
    eq(out[1], " ", "clear: paired flag collapses like a single emoji")
    eq(n, 1, "clear: flag pair counted once")
  end

  -- clear: the space-collapse needs a space on BOTH sides, so an emoji at the
  -- start or the end of a line leaves the one space it had
  do
    local patterns = require("emojis.core.patterns")
    eq(ops.clear({ "🚀 tail" })[1], " tail", "clear: no leading space means nothing to collapse")
    eq(ops.clear({ "lead 🚀" })[1], "lead ", "clear: no trailing space means nothing to collapse")
    eq(ops.clear({ "🚀" })[1], "", "clear: a line that is only an emoji empties out")
    eq(select(2, ops.clear({ "" })), 0, "clear: an empty line has nothing to remove")

    -- a stray VS16 with no base emoji is stripped silently, without counting
    local out, n = ops.clear({ "a" .. patterns.VS16 .. "b" })
    eq(out[1], "ab", "clear: a stray VS16 is stripped")
    eq(n, 0, "clear: ... and is not counted as an emoji")

    -- a VS16 trailing an emoji run belongs to the run
    out, n = ops.clear({ " 🚀" .. patterns.VS16 .. patterns.VS16 .. " " })
    eq(out[1], " ", "clear: trailing stray VS16 stays part of the run")
    eq(n, 1, "clear: ... and does not add to the count")
  end

  -- clear: multiple lines are handled independently, and the total is the sum
  do
    local out, n = ops.clear({ "a 🚀 b", "plain", "c 🔥 d" })
    eq(table.concat(out, "|"), "a b|plain|c d", "clear: per-line results")
    eq(n, 2, "clear: the count is over every line")
    eq(#ops.clear({}), 0, "clear: no lines, no output")
  end

  -- list: the line offset defaults to 0, and every span of every line is
  -- reported in reading order
  do
    local entries = ops.list({ "🚀 a 🔥", "plain", "⭐" })
    eq(#entries, 3, "list: one entry per emoji across lines")
    eq(entries[1].lnum, 1, "list: the offset defaults to 0")
    eq(entries[1].col, 0, "list: a line-leading emoji is at column 0")
    eq(entries[2].col, #"🚀 a ", "list: byte columns, not character columns")
    eq(entries[3].lnum, 3, "list: entries stay in reading order")
  end

  -- replace/wrap: the optional arguments have defaults
  do
    local out, n = ops.replace({ "a 🚀 b" })
    eq(out[1], "a :U+1F680: b", "replace: without a name map every glyph takes the fallback form")
    eq(n, 1, "replace: counted")
    eq(ops.wrap({ "a 🚀 b" })[1], "a 🚀 b", "wrap: empty markers leave the line unchanged")
    eq(ops.wrap({ "a 🚀 b" }, ">>")[1], "a >>🚀 b", "wrap: a prefix alone is allowed")
  end

  -- unreplace: tokens it does not recognize are left exactly as they are, and
  -- scanning continues after them
  do
    local names = { [0x2705] = ":white_check_mark:" }
    local out, n = ops.unreplace({ ":nope: :white_check_mark: :also_not: :U+1F680:" }, names)
    eq(out[1], ":nope: ✅ :also_not: 🚀", "unreplace: unknown tokens survive, known ones are restored")
    eq(n, 2, "unreplace: only the restored ones count")

    eq(ops.unreplace({ "no tokens here" }, names)[1], "no tokens here", "unreplace: a line without tokens is passed through")
    eq(ops.unreplace({ ":U+2705:" })[1], "✅", "unreplace: the fallback form works without a name map")
    eq(ops.unreplace({ ":U+ZZZZ:" })[1], ":U+ZZZZ:", "unreplace: a non-hex codepoint token is left alone")
    eq(ops.unreplace({ ":U+41:" })[1], "A", "unreplace: a short codepoint is rebuilt too")

    -- PRIN-25: codepoints above U+10FFFF and the UTF-16 surrogate block
    -- (U+D800-U+DFFF) are not valid Unicode scalar values; the fallback must
    -- leave both kinds of token untouched instead of emitting invalid UTF-8.
    local out_hi, n_hi = ops.unreplace({ "a :U+110000: b" })
    eq(out_hi[1], "a :U+110000: b", "unreplace: an out-of-range codepoint token is left alone")
    eq(n_hi, 0, "unreplace: an out-of-range codepoint token is not counted as restored")

    local out_sur, n_sur = ops.unreplace({ "token :U+D800: here" })
    eq(out_sur[1], "token :U+D800: here", "unreplace: a UTF-16 surrogate codepoint token is left alone")
    eq(n_sur, 0, "unreplace: a surrogate codepoint token is not counted as restored")
  end

  -- count: sums across lines, including multi-codepoint graphemes
  do
    eq(ops.count({}), 0, "count: no lines")
    eq(ops.count({ "🇩🇪 ⚠️ 👍🏽" }), 3, "count: flag, VS16 and skin-tone graphemes each count once")
  end
end
