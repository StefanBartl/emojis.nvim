-- docs/TESTS/checkbox_spec.lua — emoji checkbox cycle/add/remove on string arrays.

return function(H)
  local eq = H.eq
  local checkbox = require("emojis.core.checkbox")

  local SETS = { { "🔲", "✅", "❌" }, { "🔴", "🟡", "🟢" } }

  -- find: locates a configured glyph anywhere on the line, cursor-independent
  do
    local s, e, set_idx, pos = checkbox.find("- 🔲 1. Hallo", SETS)
    eq(s, 3, "find: byte start of the glyph")
    eq(e, 6, "find: byte end (4-byte emoji)")
    eq(set_idx, 1, "find: which set it belongs to")
    eq(pos, 1, "find: position within that set")
  end
  eq(select(1, checkbox.find("no checkbox here", SETS)), nil, "find: nil when no configured glyph present")

  -- toggle_line: advances one step, wraps at the end of the set
  do
    local line, changed = checkbox.toggle_line("🔲 1. Hallo", SETS)
    eq(line, "✅ 1. Hallo", "toggle_line: step 1")
    eq(changed, true, "toggle_line: reports a change")
  end
  do
    local line = checkbox.toggle_line("✅ 1. Hallo", SETS)
    eq(line, "❌ 1. Hallo", "toggle_line: step 2")
  end
  do
    local line = checkbox.toggle_line("❌ 1. Hallo", SETS)
    eq(line, "🔲 1. Hallo", "toggle_line: wraps back to the first state")
  end
  do
    local line, changed = checkbox.toggle_line("no glyph here", SETS)
    eq(line, "no glyph here", "toggle_line: passthrough when nothing matches")
    eq(changed, false, "toggle_line: reports no change")
  end

  -- toggle_line: cursor position is irrelevant — the glyph can be mid-line
  do
    local line = checkbox.toggle_line("1. Hallo 🔲 done", SETS)
    eq(line, "1. Hallo ✅ done", "toggle_line: line-scoped, not cursor-scoped")
  end

  -- toggle_line: backward direction
  do
    local line = checkbox.toggle_line("✅ item", SETS, -1)
    eq(line, "🔲 item", "toggle_line: dir=-1 steps backward")
  end

  -- toggle_line: ambiguous glyph resolves to the first set it appears in —
  -- "✅" belongs to set 1 here, so it cycles within {🔲,✅}, wrapping to 🔲,
  -- not into set 2's {✅,❌}.
  do
    local overlapping = { { "🔲", "✅" }, { "✅", "❌" } }
    local line = checkbox.toggle_line("✅ item", overlapping)
    eq(line, "🔲 item", "toggle_line: first-matching-set wins for an ambiguous glyph")
  end

  -- add_line / remove_line
  do
    local line, changed = checkbox.add_line("  1. Hallo", SETS)
    eq(line, "  🔲 1. Hallo", "add_line: inserts the first state, keeps indent")
    eq(changed, true, "add_line: reports a change")
  end
  eq(select(2, checkbox.add_line("", SETS)), false, "add_line: no-ops on a blank line")
  do
    local line, changed = checkbox.remove_line("🔲 1. Hallo", SETS)
    eq(line, "1. Hallo", "remove_line: strips the glyph and one following space")
    eq(changed, true, "remove_line: reports a change")
  end
  eq(select(2, checkbox.remove_line("1. Hallo", SETS)), false, "remove_line: no-ops without a glyph")

  -- toggle: batch over lines, only touches lines that already have a glyph
  do
    local out, n = checkbox.toggle({ "🔲 a", "plain b", "🔴 c" }, SETS)
    eq(out[1], "✅ a", "toggle: line 1 advances")
    eq(out[2], "plain b", "toggle: line without a glyph passes through untouched")
    eq(out[3], "🟡 c", "toggle: line 3 advances in its own set")
    eq(n, 2, "toggle: only counts lines that actually changed")
  end

  -- add: batch, skips lines that already have a glyph
  do
    local out, n = checkbox.add({ "a", "🔲 b" }, SETS)
    eq(out[1], "🔲 a", "add: adds to a plain line")
    eq(out[2], "🔲 b", "add: leaves an already-checked line alone")
    eq(n, 1, "add: only counts lines that gained a glyph")
  end

  -- remove: batch, skips lines without a glyph
  do
    local out, n = checkbox.remove({ "🔲 a", "b" }, SETS)
    eq(out[1], "a", "remove: strips from a checked line")
    eq(out[2], "b", "remove: leaves a plain line alone")
    eq(n, 1, "remove: only counts lines that lost a glyph")
  end

  -- VS16 / multi-codepoint glyphs are matched as a whole grapheme
  do
    local vs_sets = { { "⚠️", "✔️" } }
    local line = checkbox.toggle_line("⚠️ careful", vs_sets)
    eq(line, "✔️ careful", "toggle_line: variation-selector glyph matched whole, not by prefix")
  end
end
