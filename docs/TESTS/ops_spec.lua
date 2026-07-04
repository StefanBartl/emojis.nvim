-- docs/TESTS/ops_spec.lua — clear/count/list/replace on string arrays.

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
end
