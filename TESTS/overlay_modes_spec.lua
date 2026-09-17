-- TESTS/overlay_modes_spec.lua — the overlay's interaction model.
--
-- overlay_spec.lua covers the layout and the frecency ordering; this one
-- drives the grid the way a user does -- through its buffer-local keymaps,
-- with `nvim_feedkeys` -- and asserts the glyph that ends up in the buffer
-- underneath. That is the only observable the overlay has: its cell index is
-- module-private, and the insert deliberately happens after the float is gone
-- (`close_then`), so every case waits for the scheduled callback to land.
--
-- `ui.kit` is real here (ui.nvim is a sibling checkout). Only `kit.input` and
-- `kit.select` are swapped for doubles, for the two flows that would otherwise
-- block on a live prompt.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local overlay = require("emojis.overlay")
  local config = require("emojis.config")
  local frecency = require("emojis.overlay.frecency")

  local PICKS = {
    { "✅", "white_check_mark" },
    { "❌", "x" },
    { "⚠️", "warning" },
    { "🐛", "bug" },
    { "🔥", "fire" },
    { "🚀", "rocket" },
  }

  local function configure(extra)
    config.setup({
      overlay = vim.tbl_extend("force", { picks = PICKS, columns = 3, limit = 6, frecency = false }, extra or {}),
    })
  end

  --- A buffer + window for the glyph to land in, with the cursor on an empty
  --- line, and the overlay opened on top of it.
  ---@param mode string
  ---@return integer bufnr
  local function open_over(mode)
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    overlay.open(mode)
    return buf
  end

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  --- Drive the open overlay with `keys` and return the line the glyph landed on.
  ---@param buf integer
  ---@param keys string
  ---@return string
  local function after(buf, keys)
    feed(keys)
    vim.wait(2000, function()
      return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
    end, 5)
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  end

  configure()
  frecency.reset()

  -- ---------------------------------------------------------- grid movement
  -- Six picks across three columns:  ✅ ❌ ⚠️
  --                                  🐛 🔥 🚀
  do
    local buf = open_over("grid")
    eq(after(buf, "<CR>"), "✅", "grid: <CR> inserts the cell under the cursor")
    eq(overlay.is_open(), false, "grid: the overlay closed itself before inserting")
  end

  do
    local buf = open_over("grid")
    eq(after(buf, "ll<CR>"), "⚠️", "grid: l moves right, VS16 glyph inserted whole")
  end

  do
    local buf = open_over("grid")
    eq(after(buf, "j<CR>"), "🐛", "grid: j moves down one row")
  end

  do
    -- Vertical motion clamps (it does not wrap): a second j on the last row
    -- stays put, which in a grid this small reads as intended rather than as a
    -- glitch.
    local buf = open_over("grid")
    eq(after(buf, "jj<CR>"), "🐛", "grid: j on the last row clamps")
  end

  do
    local buf = open_over("grid")
    eq(after(buf, "jk<CR>"), "✅", "grid: k comes back up")
  end

  do
    -- Horizontal motion wraps across rows.
    local buf = open_over("grid")
    eq(after(buf, "lll<CR>"), "🐛", "grid: l past the last column wraps into the next row")
  end

  do
    -- ... and backwards off the first cell, where the row clamp then keeps it
    -- on the first row: h from cell 1 lands on the end of that row.
    local buf = open_over("grid")
    eq(after(buf, "h<CR>"), "⚠️", "grid: h off the first cell lands on the end of the row")
  end

  do
    local buf = open_over("grid")
    eq(after(buf, "<Down><Right><CR>"), "🔥", "grid: the arrow keys mirror hjkl")
  end

  do
    local buf = open_over("grid")
    eq(after(buf, "<Left><Up><CR>"), "⚠️", "grid: <Up> clamps at the first row, <Left> wrapped")
  end

  -- An index that would land on an empty cell of a ragged last row is refused,
  -- so <CR> still inserts a real glyph.
  do
    configure({ picks = { PICKS[1], PICKS[2], PICKS[3], PICKS[4] }, columns = 3 })
    local buf = open_over("grid")
    eq(after(buf, "jll<CR>"), "🐛", "grid: motion into an empty cell of a ragged row is ignored")
    configure()
  end

  -- -------------------------------------------------------------- closing
  do
    open_over("grid")
    feed("<Esc>")
    eq(overlay.is_open(), false, "grid: <Esc> closes")

    open_over("grid")
    feed("q")
    eq(overlay.is_open(), false, "grid: q closes")

    open_over("grid")
    overlay.close()
    eq(overlay.is_open(), false, "close(): closes the overlay")
    overlay.close()
    eq(overlay.is_open(), false, "close(): is a no-op when nothing is open")
  end

  -- ------------------------------------------------------------- grid_keys
  do
    local buf = open_over("grid_keys")
    -- The hotkeys are the home row, in cell order: a s d f g h ...
    eq(after(buf, "d"), "⚠️", "grid_keys: one keypress inserts that cell")
    eq(overlay.is_open(), false, "grid_keys: ... and closes the overlay")
  end

  do
    local buf = open_over("grid_keys")
    eq(after(buf, "s"), "❌", "grid_keys: each cell has its own key")
  end

  -- In grid_keys, "h"/"j"/"k"/"l" are hotkeys for cells 6/7/8/9 rather than
  -- motions -- the whole point of the mode, and the reason the filter hides
  -- behind "/" instead of taking a printable key.
  do
    local buf = open_over("grid_keys")
    eq(after(buf, "h"), "🚀", "grid_keys: h is the 6th cell's hotkey, not a motion")
  end

  -- ---------------------------------------------------------- the / filter
  do
    local kit = require("ui.kit")
    local real_input = kit.input
    local asked

    kit.input = function(opts)
      asked = opts.title
      opts.on_submit("fire")
    end
    local buf = open_over("grid")
    feed("/")
    vim.wait(2000, function()
      return overlay.is_open()
    end, 5)
    kit.input = real_input

    ok(asked ~= nil and asked:find("filter", 1, true) ~= nil, "filter: prompts for a query")
    local rendered = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(#rendered, 1, "filter: the grid is rebuilt with the matches only")
    ok(rendered[1]:find("🔥", 1, true) ~= nil, "filter: the match is on screen")
    ok(rendered[1]:find("✅", 1, true) == nil, "filter: everything else is gone")
    eq(after(buf, "<CR>"), "🔥", "filter: the rebuilt grid inserts the filtered glyph")
  end

  -- The glyph itself matches too, so pasting one narrows to it.
  do
    local kit = require("ui.kit")
    local real_input = kit.input
    kit.input = function(opts)
      opts.on_submit("🐛")
    end
    local buf = open_over("grid")
    feed("/")
    vim.wait(2000, function()
      return overlay.is_open()
    end, 5)
    kit.input = real_input

    eq(#vim.api.nvim_buf_get_lines(0, 0, -1, false), 1, "filter: a pasted glyph narrows to itself")
    eq(after(buf, "<CR>"), "🐛", "filter: ... and inserts it")
  end

  -- A query matching nothing keeps the grid as it was, and says so.
  do
    local kit = require("ui.kit")
    local real_input = kit.input
    kit.input = function(opts)
      opts.on_submit("nothing matches this")
    end
    open_over("grid")
    local said = H.notices(function()
      feed("/")
      vim.wait(200, function()
        return false
      end, 5)
    end)
    kit.input = real_input

    eq(said.warn[1], 'no emoji matching "nothing matches this"', "filter: an empty result is reported")
    ok(overlay.is_open(), "filter: ... and the grid stays up")
    overlay.close()
  end

  -- An empty query widens back to the full set.
  do
    local kit = require("ui.kit")
    local real_input = kit.input
    kit.input = function(opts)
      opts.on_submit("  ")
    end
    open_over("grid")
    feed("/")
    vim.wait(2000, function()
      return overlay.is_open() and #vim.api.nvim_buf_get_lines(0, 0, -1, false) == 2
    end, 5)
    kit.input = real_input

    eq(#vim.api.nvim_buf_get_lines(0, 0, -1, false), 2, "filter: an empty query keeps every pick")
    overlay.close()
  end

  -- Without ui.kit the filter cannot prompt, so `/` does nothing rather than
  -- erroring on the open grid.
  do
    open_over("grid")
    local loaded, preload = package.loaded["ui.kit"], package.preload["ui.kit"]
    package.loaded["ui.kit"] = nil
    package.preload["ui.kit"] = function()
      error("ui.kit not installed (test stub)")
    end
    feed("/")
    package.loaded["ui.kit"], package.preload["ui.kit"] = loaded, preload

    ok(overlay.is_open(), "filter: a missing ui.kit leaves the grid alone")
    overlay.close()
  end

  -- -------------------------------------------------------------- list mode
  do
    local kit = require("ui.kit")
    local real_select = kit.select
    local seen
    kit.select = function(opts)
      seen = opts
      opts.on_select(opts.items[5], 5)
    end

    local buf = open_over("list")
    kit.select = real_select

    eq(#seen.items, 6, "list: one row per pick")
    eq(seen.items[5], "🔥  :fire:", "list: rows are glyph + shortcode")
    eq(seen.title, config.get().overlay.title, "list: the configured title is passed through")
    vim.wait(2000, function()
      return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
    end, 5)
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "🔥", "list: the chosen glyph reaches the buffer")
    eq(overlay.is_open(), false, "list: the chooser is not the grid state")
  end

  -- A cancelled chooser inserts nothing.
  do
    local kit = require("ui.kit")
    local real_select = kit.select
    kit.select = function(opts)
      opts.on_select(nil, nil)
    end
    local buf = open_over("list")
    kit.select = real_select
    vim.wait(100, function()
      return false
    end, 5)
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "", "list: a cancelled selection inserts nothing")
  end

  -- --------------------------------------------------------------- entries
  -- `limit` caps the grid; the point of the overlay is that everything is
  -- reachable in one glance.
  do
    configure({ limit = 4, columns = 2 })
    open_over("grid")
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(#lines, 2, "entries: limit caps the grid at 4 cells over 2 columns")
    ok(lines[2]:find("🐛", 1, true) ~= nil, "entries: the 4th pick is the last one shown")
    ok(table.concat(lines):find("🔥", 1, true) == nil, "entries: everything past the limit is dropped")
    overlay.close()
    configure()
  end

  -- With no overlay-specific picks configured, the full catalog is used.
  do
    config.setup({ overlay = { frecency = false, columns = 4, limit = 8 } })
    config.get().overlay.picks = {}
    open_over("grid")
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(#lines, 2, "entries: falls back to config.picks when overlay.picks is empty")
    ok(lines[1]:find(config.get().picks[1][1], 1, true) ~= nil, "entries: ... starting at the catalog's first glyph")
    overlay.close()
  end

  -- With nothing at all to show, the overlay says so instead of opening empty.
  do
    config.setup({})
    config.get().overlay.picks = {}
    config.get().picks = {}
    local said = H.notices(function()
      overlay.open("grid")
    end)
    eq(said.warn[1], "no emojis configured for the overlay", "entries: an empty catalog is reported")
    eq(overlay.is_open(), false, "entries: ... and nothing opens")
    config.setup({})
  end

  -- -------------------------------------------------------- ui.kit missing
  do
    configure()
    local loaded, preload = package.loaded["ui.kit"], package.preload["ui.kit"]
    package.loaded["ui.kit"] = nil
    package.preload["ui.kit"] = function()
      error("ui.kit not installed (test stub)")
    end

    local said = H.notices(function()
      overlay.open("grid")
    end)

    package.loaded["ui.kit"], package.preload["ui.kit"] = loaded, preload
    ok(said.error[1]:find("ui.kit", 1, true) ~= nil, "open: a missing ui.nvim is reported")
    ok(said.error[1]:find("ui.nvim", 1, true) ~= nil, "open: ... with the plugin to install")
    eq(overlay.is_open(), false, "open: and nothing opens")
  end

  config.setup({})
  frecency.reset()
end
