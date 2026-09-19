-- TESTS/actions_spec.lua — the buffer-facing action handlers.
--
-- `core.ops`/`core.checkbox` are pure and covered by their own specs; this one
-- covers what sits between them and the editor: reading the target's lines,
-- writing the result back, the `word` sub-range arithmetic (byte offsets into
-- a multibyte line), the quickfix shape, and the message each branch produces.
--
-- Messages are asserted through `H.notices`, because several branches of this
-- module do nothing *but* report ("range is empty", "no emojis found in
-- scope") -- checking the buffer alone could not tell them apart from success.

return function(H)
  local eq, ok = H.eq, H.ok
  local actions = require("emojis.actions")
  local scope_m = require("emojis.core.scope")
  local config = require("emojis.config")

  config.setup({})

  ---@return Emojis.Target
  local function whole(buf)
    return { buf = buf, l1 = 0, l2 = vim.api.nvim_buf_line_count(buf) - 1 }
  end

  local function lines_of(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  -- ------------------------------------------------------------------- edit
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ship 🚀 it", "and 🔥 that", "plain" })

    local said = H.notices(function()
      actions.edit("clear", whole(buf))
    end)
    eq(lines_of(buf)[1], "ship it", "edit clear: line 1 rewritten")
    eq(lines_of(buf)[2], "and that", "edit clear: line 2 rewritten")
    eq(lines_of(buf)[3], "plain", "edit clear: an emoji-free line is left byte for byte")
    eq(said.info[1], "Removed 2 emojis", "edit clear: reports the count in plural")
  end

  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "done ✅" })

    local said = H.notices(function()
      actions.edit("replace", whole(buf))
    end)
    eq(lines_of(buf)[1], "done :white_check_mark:", "edit replace: glyph becomes its shortcode")
    eq(said.info[1], "Replaced 1 emoji", "edit replace: singular message")

    said = H.notices(function()
      actions.edit("unreplace", whole(buf))
    end)
    eq(lines_of(buf)[1], "done ✅", "edit unreplace: round-trips back to the glyph")
    eq(said.info[1], "Restored 1 emoji", "edit unreplace: its own verb")

    said = H.notices(function()
      actions.edit("wrap", whole(buf))
    end)
    eq(lines_of(buf)[1], "done [[✅]]", "edit wrap: the configured marker surrounds the glyph")
    eq(said.info[1], "Wrapped 1 emoji", "edit wrap: its own verb")
  end

  -- A configured wrap marker is read per call, not baked in at load time.
  do
    config.setup({ wrap = { prefix = "<", suffix = ">" } })
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x 🎯" })
    actions.edit("wrap", whole(buf))
    eq(lines_of(buf)[1], "x <🎯>", "edit wrap: honours a reconfigured marker")
    config.setup({})
  end

  -- `word` scope: only the byte sub-range is rewritten, and the rest of the
  -- line has to come back unchanged around it.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔥keep 🚀done ⭐tail" })
    vim.api.nvim_win_set_cursor(0, { 1, #"🔥keep " }) -- inside "🚀done"
    local target = scope_m.resolve("word", 0, 0, 0)
    ok(target ~= nil, "word scope: resolves on a multibyte line")
    ---@cast target Emojis.Target
    actions.edit("clear", target)
    eq(lines_of(buf)[1], "🔥keep done ⭐tail", "edit: a word sub-range leaves its multibyte neighbours alone")
  end

  -- A buffer edit that lands during the (non-blocking) preview window must
  -- not be silently reverted by the deferred write (ERR-30).
  do
    config.setup({ preview = { enable = true, duration_ms = 200 } })
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep 🚀 this" })

    local said = H.notices(function(record)
      actions.edit("clear", whole(buf))
      -- Concurrent edit, before the deferred write fires.
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "keep 🚀 this (edited)" })
      vim.wait(1000, function()
        return #record.warn > 0
      end, 5)
    end)
    config.setup({})

    eq(lines_of(buf)[1], "keep 🚀 this (edited)", "edit: a concurrent edit during the preview window survives")
    eq(said.warn[1], "buffer changed since the scan, skipped", "edit: the stale write is reported, not silently dropped")
  end

  -- A non-modifiable buffer is refused, not raised (ERR-01); the neighbouring
  -- `buf_ok()` refusal above only checks validity, not writability.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🚀" })
    vim.bo[buf].modifiable = false

    local said = H.notices(function()
      actions.edit("clear", whole(buf))
    end)
    eq(said.error[1], "buffer is not modifiable", "edit: a non-modifiable buffer is refused, not raised")

    vim.bo[buf].modifiable = true
    eq(lines_of(buf)[1], "🚀", "edit: ... and left untouched")
  end

  -- ---------------------------------------------------------- edit: refusals
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "nothing to do here" })
    local said = H.notices(function()
      actions.edit("clear", whole(buf))
    end)
    eq(said.info[1], "no emojis found in scope", "edit: an emoji-free scope is reported, not rewritten")
    eq(lines_of(buf)[1], "nothing to do here", "edit: ... and the line is untouched")
  end

  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🚀" })
    local target = whole(buf)
    local keep = H.scratch()
    vim.api.nvim_buf_delete(buf, { force = true })

    local said = H.notices(function()
      actions.edit("clear", target)
    end)
    eq(said.error[1], "buffer is no longer valid", "edit: a stale target is refused")
    eq(#said.info, 0, "edit: ... without also claiming success")
    ok(vim.api.nvim_buf_is_valid(keep), "edit: the current buffer is not the one it complained about")
  end

  -- An out-of-range target reads back zero lines.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one line" })
    local said = H.notices(function()
      actions.edit("clear", { buf = buf, l1 = 5, l2 = 9 })
    end)
    eq(said.info[1], "range is empty", "edit: an empty range is reported")
  end

  -- -------------------------------------------------------------- list (qf)
  -- `lib.nvim.ui.list.qf` opens the quickfix window, which would then be the
  -- current one for every case after this; each list case closes it again.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b", "plain", "c ⚠️ d 🔥" })

    local said = H.notices(function()
      actions.list(whole(buf))
    end)
    vim.cmd("cclose")
    local qf = vim.fn.getqflist()
    eq(#qf, 3, "list: one quickfix entry per emoji")
    eq(qf[1].lnum, 1, "list: 1-based line numbers")
    eq(qf[1].col, 3, "list: 1-based byte column")
    eq(qf[1].text, "emoji 🚀", "list: the glyph is in the entry text")
    eq(qf[3].lnum, 3, "list: the last entry's line")
    eq(qf[3].col, 1 + #"c ⚠️ d ", "list: a column past a multibyte glyph counts bytes")
    eq(said.info[1], "Found 3 emojis -> quickfix", "list: reports the total")
    eq(vim.fn.getqflist({ title = 0 }).title, "Emojis", "list: the quickfix list is titled")
  end

  -- A `word` sub-range shifts every reported column back onto the full line.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "lead 🚀tail" })
    vim.api.nvim_win_set_cursor(0, { 1, #"lead " })
    local target = scope_m.resolve("word", 0, 0, 0)
    ---@cast target Emojis.Target
    actions.list(target)
    vim.cmd("cclose")
    local qf = vim.fn.getqflist()
    eq(#qf, 1, "list word scope: only the word's emoji")
    eq(qf[1].col, #"lead " + 1, "list word scope: the column is offset back onto the full line")
  end

  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no glyphs" })
    local said = H.notices(function()
      actions.list(whole(buf))
    end)
    eq(said.info[1], "no emojis found in scope", "list: an empty result is reported")

    said = H.notices(function()
      actions.list({ buf = -1, l1 = 0, l2 = 0 })
    end)
    eq(said.error[1], "buffer is no longer valid", "list: the cwd sentinel target is refused here")
  end

  -- ------------------------------------------------------------------ count
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b", "c ⚠️ d" })
    local said = H.notices(function()
      actions.count(whole(buf))
    end)
    eq(said.info[1], "Found 2 emojis in 2 lines", "count: plural glyphs and lines")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "only 🚀" })
    said = H.notices(function()
      actions.count({ buf = buf, l1 = 0, l2 = 0 })
    end)
    eq(said.info[1], "Found 1 emoji in 1 line", "count: singular glyph and line")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "none", "here" })
    said = H.notices(function()
      actions.count(whole(buf))
    end)
    eq(said.info[1], "no emojis in 2 lines", "count: the zero case has its own wording")

    said = H.notices(function()
      actions.count({ buf = 99999, l1 = 0, l2 = 0 })
    end)
    eq(said.error[1], "buffer is no longer valid", "count: an unknown buffer is refused")
  end

  -- --------------------------------------------------------------- checkbox
  do
    config.setup({
      checkbox = {
        sets = { checkbox = { "🔲", "✅" }, status = { "🔴", "🟡", "🟢" } },
        order = { "checkbox", "status" },
      },
    })

    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a", "prose", "🔴 c" })

    local said = H.notices(function()
      actions.checkbox("toggle", whole(buf))
    end)
    eq(lines_of(buf)[1], "✅ a", "checkbox toggle: advances within its own set")
    eq(lines_of(buf)[2], "prose", "checkbox toggle: a line without a glyph is never given one")
    eq(lines_of(buf)[3], "🟡 c", "checkbox toggle: a second set advances independently")
    eq(said.info[1], "Toggled 2 checkboxes", "checkbox toggle: counts only the lines that changed")

    -- A named set restricts the search to that cycle.
    said = H.notices(function()
      actions.checkbox("toggle", whole(buf), "status")
    end)
    eq(lines_of(buf)[1], "✅ a", "checkbox toggle status: the other set's line is untouched")
    eq(lines_of(buf)[3], "🟢 c", "checkbox toggle status: only the named set advances")
    eq(said.info[1], "Toggled 1 checkbox", "checkbox: singular message")

    -- Backward.
    H.notices(function()
      actions.checkbox("toggle", whole(buf), "status", -1)
    end)
    eq(lines_of(buf)[3], "🟡 c", "checkbox toggle: dir = -1 steps backward")

    -- add / remove over the same range.
    said = H.notices(function()
      actions.checkbox("add", whole(buf))
    end)
    eq(lines_of(buf)[2], "🔲 prose", "checkbox add: the first set's first glyph is prepended")
    eq(said.info[1], "Added 1 checkbox", "checkbox add: only the line that gained one counts")

    said = H.notices(function()
      actions.checkbox("add", whole(buf))
    end)
    eq(said.info[1], "every line already has a checkbox", "checkbox add: its own empty-result wording")

    said = H.notices(function()
      actions.checkbox("remove", whole(buf))
    end)
    eq(lines_of(buf)[1], "a", "checkbox remove: the glyph and one space are stripped")
    eq(lines_of(buf)[2], "prose", "checkbox remove: back to the original line")
    eq(said.info[1], "Removed 3 checkboxes", "checkbox remove: counts every stripped line")

    said = H.notices(function()
      actions.checkbox("toggle", whole(buf))
    end)
    eq(said.info[1], "no checkbox found in scope", "checkbox toggle: nothing to toggle is reported")
  end

  -- The `word` sub-range is deliberately ignored: a checkbox belongs to its
  -- line, so the scope only ever selects WHICH lines are affected.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 tail word" })
    vim.api.nvim_win_set_cursor(0, { 1, #"🔲 tail " }) -- on "word", not on the glyph
    local target = scope_m.resolve("word", 0, 0, 0)
    ---@cast target Emojis.Target
    actions.checkbox("toggle", target)
    eq(lines_of(buf)[1], "✅ tail word", "checkbox: a word sub-range still toggles the whole line")
  end

  -- ------------------------------------------------------- checkbox refusals
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a" })

    local said = H.notices(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      actions.checkbox("frobnicate", whole(buf))
    end)
    eq(said.error[1], 'unknown checkbox op "frobnicate"', "checkbox: an unknown op is refused")

    said = H.notices(function()
      actions.checkbox("toggle", whole(buf), "nosuchset")
    end)
    ok(said.error[1]:find('unknown checkbox set "nosuchset"', 1, true) ~= nil, "checkbox: an unknown set is refused")
    ok(said.error[1]:find("Valid: ", 1, true) ~= nil, "checkbox: ... and the valid names are listed")
    ok(said.error[1]:find("checkbox", 1, true) ~= nil, "checkbox: ... including the configured ones")
    ok(said.error[1]:find("status", 1, true) ~= nil, "checkbox: ... all of them")
    eq(lines_of(buf)[1], "🔲 a", "checkbox: a refused call leaves the buffer alone")

    said = H.notices(function()
      actions.checkbox("toggle", { buf = -1, l1 = 0, l2 = 0 })
    end)
    eq(said.error[1], "buffer is no longer valid", "checkbox: a stale target is refused")

    said = H.notices(function()
      actions.checkbox("toggle", { buf = buf, l1 = 7, l2 = 9 })
    end)
    eq(said.info[1], "range is empty", "checkbox: an empty range is reported")

    -- A non-modifiable buffer is refused, not raised (ERR-01). `toggle` on
    -- "🔲 a" always finds a glyph to cycle, so it reaches the write.
    vim.bo[buf].modifiable = false
    said = H.notices(function()
      actions.checkbox("toggle", whole(buf))
    end)
    eq(said.error[1], "buffer is not modifiable", "checkbox: a non-modifiable buffer is refused, not raised")
    vim.bo[buf].modifiable = true
    eq(lines_of(buf)[1], "🔲 a", "checkbox: ... and left untouched")
  end

  -- With every set removed there is nothing to cycle through, which is a
  -- configuration problem rather than "nothing to toggle". `setup({})` cannot
  -- express it (an empty table merges as "change nothing"), so the active
  -- config -- which `get()` hands out live -- is emptied directly.
  do
    config.setup({})
    config.get().checkbox.sets = {}
    config.get().checkbox.order = {}
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a" })
    local said = H.notices(function()
      actions.checkbox("toggle", whole(buf))
    end)
    eq(said.warn[1], "no checkbox sets configured", "checkbox: an empty set list is a warning of its own")
  end

  config.setup({})
end
