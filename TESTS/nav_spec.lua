-- TESTS/nav_spec.lua — cursor navigation to the first / next emoji.
--
-- commands_spec.lua drives `:Emojis first|next` through the command layer;
-- this one goes at `emojis.nav` directly, for the cases the command form
-- cannot express: an emoji-free buffer, the notice it suppresses mid-walk, a
-- cursor sitting on the glyph itself, and the byte columns it reports.

return function(H)
  local eq, ok = H.eq, H.ok
  local nav = require("emojis.nav")

  -- ------------------------------------------------------------------ first
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain", "text ⚠️ here", "🚀 top" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    nav.first()
    local pos = vim.api.nvim_win_get_cursor(0)
    eq(pos[1], 2, "first: scans from the top of the buffer, not from the cursor")
    eq(pos[2], #"text ", "first: lands on the glyph's first byte")
  end

  -- `first` does not wrap: with nothing below the start there is nothing to
  -- find, and it says so.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no", "emoji", "at all" })
    vim.api.nvim_win_set_cursor(0, { 2, 1 })

    local said = H.notices(function()
      nav.first()
    end)
    eq(#said.info, 1, "first: reports an emoji-free buffer")
    eq(said.info[1], "no emoji found", "first: with the documented message")
    eq(vim.api.nvim_win_get_cursor(0)[1], 2, "first: leaves the cursor where it was")
  end

  -- ------------------------------------------------------------------- next
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b 🔥 c", "d ⭐ e" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    nav.next()
    eq(vim.api.nvim_win_get_cursor(0)[2], 2, "next: first emoji on the cursor line")

    -- Standing ON a glyph must move past it, not stay put: the scan starts one
    -- byte after the cursor, and a 4-byte glyph's own span begins before that.
    nav.next()
    eq(vim.api.nvim_win_get_cursor(0)[2], #"a 🚀 b ", "next: steps off the glyph the cursor sits on")

    nav.next()
    eq(vim.api.nvim_win_get_cursor(0)[1], 2, "next: continues onto the following line")

    -- Past the last one it wraps to the top of the buffer.
    nav.next()
    eq(vim.api.nvim_win_get_cursor(0)[1], 1, "next: wraps around")
    eq(vim.api.nvim_win_get_cursor(0)[2], 2, "next: ... to the first emoji")
  end

  -- A count walks step by step, so the wrap stays correct at every step.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🚀 one", "🔥 two", "⭐ three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    nav.next(2)
    eq(vim.api.nvim_win_get_cursor(0)[1], 3, "next(2): two emoji forward")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    nav.next(4) -- 3 emoji in the buffer: 1 -> 2 -> 3 -> wrap to 1 -> 2
    eq(vim.api.nvim_win_get_cursor(0)[1], 2, "next(4): keeps stepping past the wrap")

    -- A non-positive count is rejected rather than silently clamped to one
    -- step (PRIN-25): the cursor stays put, and the rejection is reported.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local said = H.notices(function()
      nav.next(0)
    end)
    eq(vim.api.nvim_win_get_cursor(0)[1], 1, "next(0): rejected, the cursor does not move")
    ok(said.warn[1]:find("invalid count", 1, true) ~= nil, "next(0): the rejection is reported")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    said = H.notices(function()
      nav.next(-3)
    end)
    eq(vim.api.nvim_win_get_cursor(0)[1], 1, "next(-3): rejected too")
    ok(said.warn[1]:find("invalid count", 1, true) ~= nil, "next(-3): the rejection is reported")
  end

  -- An absurd count is capped rather than spinning the main loop unbounded.
  -- Same 3-emoji buffer and stepping cycle as the block above (count=4 lands
  -- on row 2 there); MAX_COUNT (1000) is 1 mod 3, the same residue as
  -- count=4 (1 mod 3), so capping must land on the same row.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🚀 one", "🔥 two", "⭐ three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local said = H.notices(function()
      nav.next(1e9)
    end)
    ok(said.warn[1]:find("exceeds the max", 1, true) ~= nil, "next(huge): the cap is reported")
    eq(vim.api.nvim_win_get_cursor(0)[1], 2, "next(huge): capped at MAX_COUNT, still lands deterministically")
  end

  -- A walk that runs out mid-way stays quiet: it has already moved, so "no
  -- emoji found" would be both wrong and repeated once per remaining step.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "only 🚀 one" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local said = H.notices(function()
      nav.next(3)
    end)
    eq(#said.info, 0, "next(3): a walk that runs out mid-way reports nothing")
    eq(vim.api.nvim_win_get_cursor(0)[2], #"only ", "next(3): and stays on the one emoji it found")
  end

  -- The first step of a walk that finds nothing at all DOES report.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "nothing here" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local said = H.notices(function()
      nav.next()
    end)
    eq(#said.info, 1, "next: an emoji-free buffer is reported once")
  end
end
