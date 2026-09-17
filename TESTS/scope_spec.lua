-- TESTS/scope_spec.lua — scope resolution: %, line, word, visual, range, cwd.
---@diagnostic disable: need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local scope_m = require("emojis.core.scope")

  local buf = H.scratch()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })

  -- "%": whole buffer, 0-based inclusive
  do
    local t = scope_m.resolve("%", 0, 0, 0)
    eq(t.l1, 0, "%: first line")
    eq(t.l2, 2, "%: last line")
  end

  -- "line": current cursor line only
  do
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local t = scope_m.resolve("line", 0, 0, 0)
    eq(t.l1, 1, "line: 0-based cursor line")
    eq(t.l2, 1, "line: single-line range")
  end

  -- explicit Vim range overrides the scope keyword
  do
    local t = scope_m.resolve("%", 2, 1, 2)
    eq(t.l1, 0, "range: overrides scope, start")
    eq(t.l2, 1, "range: overrides scope, end")
  end

  -- "cwd": sentinel target (buf == -1), no buffer touched
  do
    local t = scope_m.resolve("cwd", 0, 0, 0)
    eq(t.buf, -1, "cwd: sentinel buffer")
  end

  -- "visual": errors without a prior visual selection
  do
    vim.cmd("normal! \27") -- clear any pending mode
    local t, err = scope_m.resolve("visual", 0, 0, 0)
    if t == nil then
      eq(type(err), "string", "visual: error message when unset")
    end
  end

  -- unknown scope
  do
    local t, err = scope_m.resolve("bogus", 0, 0, 0)
    eq(t, nil, "unknown scope: no target")
    eq(err, "unknown scope: bogus", "unknown scope: error message")
  end

  -- "word": whitespace-delimited run around the cursor byte column
  -- (uses its own buffer; run last so it doesn't disturb the 3-line fixture above)
  do
    local wbuf = H.scratch()
    vim.api.nvim_buf_set_lines(wbuf, 0, -1, false, { "hello world foo" })
    vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- inside "world" (0-based col 6-10)
    local t = scope_m.resolve("word", 0, 0, 0)
    eq(t.l1, 0, "word: cursor line")
    eq(t.c1, 7, "word: start column")
    eq(t.c2, 11, "word: end column")

    vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- the space between "hello" and "world"
    local t2, err = scope_m.resolve("word", 0, 0, 0)
    eq(t2, nil, "word: no target on whitespace")
    eq(err, "cursor is not on a word", "word: whitespace error message")
  end

  -- a range wider than the buffer is clamped to it, in both directions
  do
    local rbuf = H.scratch()
    vim.api.nvim_buf_set_lines(rbuf, 0, -1, false, { "one", "two" })
    local t = scope_m.resolve("%", 2, 0, 99)
    eq(t.l1, 0, "range: a start before the first line clamps to 0")
    eq(t.l2, 1, "range: an end past the last line clamps to it")
  end

  -- "%" on an empty buffer is still a valid single-line target: Neovim buffers
  -- always have at least one (empty) line.
  do
    H.scratch()
    local t = scope_m.resolve("%", 0, 0, 0)
    eq(t.l1, 0, "%: empty buffer, first line")
    eq(t.l2, 0, "%: empty buffer, same line")
  end

  -- "word" at the very start and the very end of a line, and across a tab
  do
    local wbuf = H.scratch()
    vim.api.nvim_buf_set_lines(wbuf, 0, -1, false, { "alpha\tbeta gamma" })

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local t = scope_m.resolve("word", 0, 0, 0)
    eq(t.c1, 1, "word: a word at the line start begins at byte 1")
    eq(t.c2, 5, "word: ... and ends before the tab")

    vim.api.nvim_win_set_cursor(0, { 1, #"alpha\tbeta gamm" })
    t = scope_m.resolve("word", 0, 0, 0)
    eq(t.c1, #"alpha\tbeta " + 1, "word: the last word starts after the space")
    eq(t.c2, #"alpha\tbeta gamma", "word: ... and runs to the end of the line")

    vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- on the tab itself
    eq(scope_m.resolve("word", 0, 0, 0), nil, "word: a tab is whitespace too")
  end

  -- "word" on an empty line has nothing to select
  do
    H.scratch()
    local t, err = scope_m.resolve("word", 0, 0, 0)
    eq(t, nil, "word: no target on an empty line")
    eq(err, "cursor line is empty", "word: empty-line error message")
  end

  -- a visual selection that outlives the lines it was made on is clamped to
  -- what is left of the buffer
  do
    local vbuf = H.scratch()
    vim.api.nvim_buf_set_lines(vbuf, 0, -1, false, { "a", "b", "c", "d" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("Vjj<Esc>", true, false, true), "x", false)
    vim.api.nvim_buf_set_lines(vbuf, 2, 4, false, {}) -- the tail of the selection is gone

    local t = scope_m.resolve("visual", 0, 0, 0)
    eq(t.l1, 1, "visual: the start of the selection")
    eq(t.l2, 1, "visual: the end is clamped to the last remaining line")
  end
end
