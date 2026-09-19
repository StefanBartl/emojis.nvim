-- TESTS/unicode_spec.lua — emojis.unicode: info()/name_at_cursor()/search()/
-- dispatch(). The UCD download (emojis.unicode.data.ensure) is stubbed
-- throughout — this suite is about the logic built on top of it, not the
-- network fetch itself (unicode_data_spec.lua covers the parser in
-- isolation, with no I/O at all).

return function(H)
  local eq, ok = H.eq, H.ok
  local unicode = require("emojis.unicode")
  local data_mod = require("emojis.unicode.data")

  require("emojis").setup({})

  --- Replace data_mod.ensure for the duration of `fn`, returning a fixed
  --- { by_cp, list, ranges } (or an error) instead of touching the network.
  ---@param stub fun(): table|nil, string|nil
  ---@param fn fun(): nil
  local function with_stub_data(stub, fn)
    local real = data_mod.ensure
    data_mod.ensure = stub
    local called_ok, err = pcall(fn)
    data_mod.ensure = real
    if not called_ok then
      error(err, 0)
    end
  end

  local FIXED_DATA = {
    by_cp = { [0x00E9] = "LATIN SMALL LETTER E WITH ACUTE" },
    list = {
      { cp = 0x00E9, name = "LATIN SMALL LETTER E WITH ACUTE" },
    },
    ranges = {},
  }

  -- ------------------------------------------------------------------- info
  with_stub_data(function()
    return FIXED_DATA
  end, function()
    local info = unicode.info(0x00E9)
    eq(info.hex, "U+00E9", "info: hex")
    eq(info.dec, "233", "info: dec")
    eq(info.glyph, "é", "info: glyph re-encoded from the codepoint")
    eq(info.name, "LATIN SMALL LETTER E WITH ACUTE", "info: name from the UCD table")
    eq(info.html, "&#xE9;", "info: html entity")
    ok(vim.tbl_contains(info.digraphs, "e'"), "info: digraph e' found for é")
  end)

  -- A curated emojis.nvim glyph resolves its name WITHOUT touching data_mod
  -- at all -- the stub below errors if it is ever called, so this also
  -- proves the fast path never falls through to the UCD.
  do
    local called = false
    local real = data_mod.ensure
    data_mod.ensure = function()
      called = true
      return nil, "should not be called"
    end
    local info = unicode.info(require("emojis.core.patterns").codepoint("✅"))
    data_mod.ensure = real
    eq(info.name, "WHITE CHECK MARK", "info: curated catalog name, prettified")
    ok(not called, "info: curated hit never calls data_mod.ensure")
  end

  -- ---------------------------------------------------------- name_at_cursor
  with_stub_data(function()
    return FIXED_DATA
  end, function()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "café" })
    vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- byte col of "é" (c-a-f- = 3 bytes)

    local said = H.notices(function()
      unicode.name_at_cursor(nil, nil)
    end)
    ok(#said.info == 1, "name_at_cursor: reports once")
    ok(said.info[1]:find("U%+00E9") ~= nil, "name_at_cursor: reports the right codepoint")
    ok(said.info[1]:find("LATIN SMALL LETTER E WITH ACUTE", 1, true) ~= nil, "name_at_cursor: reports the name")

    -- Register save: type "value" saves the decimal codepoint.
    said = H.notices(function()
      unicode.name_at_cursor("z", "value")
    end)
    eq(vim.fn.getreg("z"), "233", "name_at_cursor: register z holds the decimal value")
    ok(said.info[#said.info]:find("register", 1, true) ~= nil, "name_at_cursor: confirms the save")

    -- The "=" register evaluates its contents as Vimscript on every read --
    -- never let a UCD-sourced (network/cache) name string reach it. Not
    -- reading @= back here at all (even via getreg) -- doing so would
    -- evaluate whatever is in it, which is exactly the hazard under test.
    said = H.notices(function()
      unicode.name_at_cursor("=", "value")
    end)
    eq(#said.error, 1, 'name_at_cursor: refuses to save into the "=" register')
    ok(said.error[1]:find('"="', 1, true) ~= nil, "name_at_cursor: names the offending register")
  end)

  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local said = H.notices(function()
      unicode.name_at_cursor(nil, nil)
    end)
    eq(#said.info, 1, "name_at_cursor: empty line still reports (nothing under cursor)")
    ok(said.info[1]:find("no character", 1, true) ~= nil, "name_at_cursor: says so")
  end

  -- --------------------------------------------------------------- dispatch
  with_stub_data(function()
    return FIXED_DATA
  end, function()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local said = H.notices(function()
      unicode.dispatch({ "unicode", "name" }, false)
    end)
    eq(#said.info, 1, "dispatch(name): reaches name_at_cursor")

    said = H.notices(function()
      unicode.dispatch({ "unicode", "bogus" }, false)
    end)
    eq(#said.error, 1, "dispatch: unknown sub-action is refused")
    ok(said.error[1]:find('unknown unicode sub%-action "bogus"') ~= nil, "dispatch: names the offending token")
  end)

  -- search: a U+xxxx query resolves to exactly that one codepoint, without
  -- ever running the substring scan over cfg_names/data.list (a second,
  -- decoy-named entry in the fixture would show up in the result if the
  -- scan ran too).
  with_stub_data(function()
    return {
      by_cp = { [0x0041] = "LATIN CAPITAL LETTER A", [0x0042] = "DECOY, MUST NOT APPEAR" },
      list = {
        { cp = 0x0041, name = "LATIN CAPITAL LETTER A" },
        { cp = 0x0042, name = "DECOY, MUST NOT APPEAR" },
      },
      ranges = {},
    }
  end, function()
    -- vim.ui.select is stubbed to auto-pick the first (only) result.
    local real_select = vim.ui.select
    local picked
    vim.ui.select = function(items, _, on_choice)
      eq(#items, 1, "search: a U+xxxx query yields exactly one result, not a scan")
      picked = items[1]
      on_choice(picked)
    end
    local said = H.notices(function()
      unicode.search("U+0041", false)
    end)
    vim.ui.select = real_select
    ok(picked ~= nil and picked.cp == 0x0041, "search: resolves the exact codepoint")
    ok(said.info[#said.info]:find("U%+0041") ~= nil, "search: reports the picked entry")
  end)

  -- search: an ordinary name query DOES scan, and finds the decoy.
  with_stub_data(function()
    return {
      by_cp = {},
      list = {
        { cp = 0x0041, name = "LATIN CAPITAL LETTER A" },
        { cp = 0x0042, name = "DECOY MATCH" },
      },
      ranges = {},
    }
  end, function()
    local real_select = vim.ui.select
    local picked_count = 0
    vim.ui.select = function(items, _, on_choice)
      picked_count = #items
      on_choice(items[1])
    end
    H.notices(function()
      unicode.search("decoy", false)
    end)
    vim.ui.select = real_select
    eq(picked_count, 1, "search: name substring scan finds the matching entry")
  end)

  -- table_open(): a second call while the first window is still open must
  -- reuse the existing named buffer/window rather than colliding on the
  -- name (nvim_buf_set_name raises E95 on a duplicate name) and leaving a
  -- stray unnamed buffer behind.
  with_stub_data(function()
    return {
      by_cp = {},
      list = { { cp = 0x0041, name = "LATIN CAPITAL LETTER A" } },
      ranges = {},
    }
  end, function()
    ok(vim.fn.bufnr("Unicode Table") == -1, "table_open: no stray buffer before the test")

    unicode.table_open()
    local buf1 = vim.fn.bufnr("Unicode Table")
    ok(buf1 ~= -1, "table_open: creates a named buffer")
    local win1 = vim.fn.bufwinid(buf1)
    ok(win1 ~= -1, "table_open: opens it in a window")

    local buf_count_before = #vim.api.nvim_list_bufs()
    unicode.table_open()
    eq(#vim.api.nvim_list_bufs(), buf_count_before, "table_open: a second call creates no new buffer")
    eq(vim.fn.bufnr("Unicode Table"), buf1, "table_open: reuses the same named buffer")
    eq(vim.api.nvim_get_current_win(), win1, "table_open: jumps to the already-open window instead of splitting again")

    pcall(vim.api.nvim_buf_delete, buf1, { force = true })
  end)

  -- digraphs_open(): the same open_named_scratch() helper, smoke-tested.
  do
    ok(vim.fn.bufnr("Digraphs") == -1, "digraphs_open: no stray buffer before the test")
    unicode.digraphs_open()
    local buf1 = vim.fn.bufnr("Digraphs")
    ok(buf1 ~= -1, "digraphs_open: creates a named buffer")

    local buf_count_before = #vim.api.nvim_list_bufs()
    unicode.digraphs_open()
    eq(#vim.api.nvim_list_bufs(), buf_count_before, "digraphs_open: a second call creates no new buffer")
    eq(vim.fn.bufnr("Digraphs"), buf1, "digraphs_open: reuses the same named buffer")

    pcall(vim.api.nvim_buf_delete, buf1, { force = true })
  end
end
