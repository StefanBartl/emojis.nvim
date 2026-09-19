-- TESTS/insert_spec.lua — core.insert: the one place a glyph reaches a buffer.
--
-- Asserts the resulting line byte for byte rather than "did not error": the
-- interesting part of inserting an emoji is that the cursor column is a *byte*
-- offset while the glyph is 3-4 bytes wide, so an off-by-one lands the glyph
-- inside the previous character and produces mojibake instead of a crash.
--
-- The frecency store is redirected to a temp file by run.lua, so recording a
-- use here never touches the developer's real history.

return function(H)
  local eq = H.eq
  local insert = require("emojis.core.insert")
  local config = require("emojis.config")
  local frecency = require("emojis.overlay.frecency")

  config.setup({})

  local function line_of(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  end

  -- ------------------------------------------------------- plain ASCII line
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
    vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- between "a" and "b"

    eq(insert.at_cursor("🚀"), true, "at_cursor: reports the insertion")
    eq(line_of(buf), "a🚀b", "at_cursor: glyph lands exactly at the cursor byte")
    eq(vim.api.nvim_win_get_cursor(0)[2], 1 + #"🚀", "at_cursor: cursor advances by the glyph's byte length")
  end

  -- --------------------------------------------- inserting next to multibyte
  -- The cursor column is a byte offset: after one emoji it is 4, not 1. The
  -- second glyph must land after the first, not inside it.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🚀x" })
    vim.api.nvim_win_set_cursor(0, { 1, #"🚀" }) -- between the rocket and "x"

    insert.at_cursor("🔥")
    eq(line_of(buf), "🚀🔥x", "at_cursor: inserts between two multibyte neighbours")
    eq(vim.fn.strchars(line_of(buf)), 3, "at_cursor: the line still holds three characters, not a split grapheme")
  end

  -- A multi-codepoint glyph (VS16) keeps all of its bytes together.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    insert.at_cursor("⚠️")
    eq(line_of(buf), "⚠️", "at_cursor: a VS16 glyph is inserted whole")
    eq(require("emojis.core.patterns").count(line_of(buf)), 1, "at_cursor: and reads back as one grapheme")
  end

  -- ---------------------------------------------------- end-of-line insertion
  -- Insertion is "before the cursor", so in normal mode -- where the cursor
  -- cannot sit past the last character -- a glyph picked with the cursor at
  -- the end of the line lands before that character, exactly like `i` would.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
    vim.api.nvim_win_set_cursor(0, { 1, #"ab" })
    eq(vim.api.nvim_win_get_cursor(0)[2], 1, "normal mode clamps the cursor to the last character")

    insert.at_cursor("✅")
    eq(line_of(buf), "a✅b", "at_cursor: inserts before the cursor, like `i`")
  end

  -- With the cursor genuinely past the last character -- the insert-mode
  -- position, which `<C-e>` is bound in as well -- the glyph is appended.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
    local ve = vim.o.virtualedit
    vim.o.virtualedit = "onemore"
    vim.api.nvim_win_set_cursor(0, { 1, #"ab" })

    eq(insert.at_cursor("✅"), true, "at_cursor: inserts at the end of the line")
    eq(line_of(buf), "ab✅", "at_cursor: appended, nothing overwritten")
    eq(vim.api.nvim_win_get_cursor(0)[2], #"ab✅", "at_cursor: the cursor follows the glyph")
    vim.o.virtualedit = ve
  end

  -- An empty line is the degenerate case of the same arithmetic.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    insert.at_cursor("✅")
    eq(line_of(buf), "✅", "at_cursor: an empty line takes the glyph alone")
  end

  -- ------------------------------------------------------------- rejections
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep" })
    vim.api.nvim_win_set_cursor(0, { 1, 2 })

    eq(insert.at_cursor(""), false, "at_cursor: refuses an empty glyph")
    ---@diagnostic disable-next-line: param-type-mismatch
    eq(insert.at_cursor(nil), false, "at_cursor: refuses a nil glyph")
    ---@diagnostic disable-next-line: param-type-mismatch
    eq(insert.at_cursor(42), false, "at_cursor: refuses a non-string glyph")
    eq(line_of(buf), "keep", "at_cursor: a rejected insert leaves the line alone")
  end

  -- A non-modifiable current buffer is refused, not raised (ERR-01).
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep" })
    vim.api.nvim_win_set_cursor(0, { 1, 2 })
    vim.bo[buf].modifiable = false

    eq(insert.at_cursor("🚀"), false, "at_cursor: a non-modifiable buffer returns false, not a raise")

    vim.bo[buf].modifiable = true
    eq(line_of(buf), "keep", "at_cursor: ... and the line is untouched")
  end

  -- -------------------------------------------------------- frecency wiring
  -- Recording is tied to insertion rather than to a UI layer, so every entry
  -- point feeds the same histogram. That is the whole contract of this module
  -- beyond the byte arithmetic above.
  do
    frecency.reset()
    local picks = { { "✅", "white_check_mark" }, { "🚀", "rocket" } }
    eq(frecency.sort(picks)[1][1], "✅", "frecency: curated order before any insert")

    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    insert.at_cursor("🚀")
    insert.at_cursor("🚀")

    eq(frecency.sort(picks)[1][1], "🚀", "at_cursor: the insertion is recorded for frecency")
    frecency.reset()
  end

  -- With `overlay.frecency = false` the insert still happens, but nothing is
  -- recorded — opting out of the feature also opts out of the disk write.
  do
    config.setup({ overlay = { frecency = false } })
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    insert.at_cursor("🔥")

    eq(line_of(buf), "🔥", "at_cursor: inserts regardless of the frecency setting")
    local picks = { { "✅", "white_check_mark" }, { "🔥", "fire" } }
    eq(frecency.sort(picks)[1][1], "✅", "at_cursor: nothing recorded with overlay.frecency = false")
    config.setup({})
    frecency.reset()
  end
end
