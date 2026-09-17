-- TESTS/api_spec.lua — the public Lua API in emojis/init.lua.
--
-- Everything here is what a user's own config calls: `require("emojis").x()`.
-- The interesting part is `checkbox_target()`, the private resolver behind
-- toggle/checkbox_add/checkbox_remove, which picks between three sources for
-- its line range (visual selection, cursor line, cursor line + count). The
-- count and visual branches are only reachable through a real mapping, so
-- those cases go through `nvim_feedkeys` on a mapping declared exactly like
-- the preset's `toggle` action (mode `{ "n", "x" }`, see bindings/keymaps.lua).
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq = H.eq
  local emojis = require("emojis")
  local config = require("emojis.config")

  config.setup({})

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  local function boxes()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a", "🔲 b", "🔲 c", "🔲 d" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    return buf
  end

  local function lines_of(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "|")
  end

  -- ------------------------------------------------------------------ setup
  -- setup() is idempotent: the first call wins, so a second one -- from a
  -- second plugin manager entry, or a user re-sourcing their config -- cannot
  -- register a second command or re-bind anything.
  do
    emojis.setup({}) -- a no-op if an earlier spec already ran it
    eq(vim.g.loaded_emojis, 1, "setup: the load guard is set")
    emojis.setup({ command = "EmojisSecondSetup" })
    eq(vim.fn.exists(":EmojisSecondSetup"), 0, "setup: a second call is a no-op")
    eq(vim.fn.exists(":Emojis"), 2, "setup: the first registration stands")
  end

  -- ------------------------------------------------------------- delegation
  do
    local picker = require("emojis.picker")
    local real = picker.insert
    local calls = 0
    picker.insert = function()
      calls = calls + 1
    end
    emojis.insert()
    picker.insert = real
    eq(calls, 1, "insert: delegates to the picker")
  end

  do
    local overlay = require("emojis.overlay")
    local real = overlay.open
    local seen = {}
    overlay.open = function(mode)
      seen[#seen + 1] = { mode } -- boxed: a nil mode is a call, not a gap
    end
    emojis.overlay()
    emojis.overlay("list")
    overlay.open = real
    eq(#seen, 2, "overlay: both calls arrived")
    eq(seen[1][1], nil, "overlay: no mode means the configured default")
    eq(seen[2][1], "list", "overlay: an explicit mode is forwarded")
  end

  eq(emojis.ops(), require("emojis.core.ops"), "ops: hands out the pure operations for scripting")

  -- --------------------------------------------------------- whole-buffer API
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b", "c ⭐ d" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local said = H.notices(function()
      emojis.count()
    end)
    eq(said.info[1], "Found 2 emojis in 2 lines", "count: the whole buffer, not the cursor line")

    emojis.clear()
    eq(lines_of(buf), "a b|c d", "clear: the whole buffer, from any cursor position")
  end

  -- ------------------------------------------------------- cascade_groups()
  do
    local groups = emojis.cascade_groups()
    eq(#groups, 3, "cascade_groups: one group per configured set")
    eq(type(groups[1][1]), "string", "cascade_groups: groups are lists of glyphs")

    -- A deep copy: cascade is free to keep and even mutate what it is given,
    -- and this plugin's own configuration must not move underneath it.
    groups[1][1] = "MUTATED"
    eq(config.get().checkbox.sets.checkbox[1], "🔲", "cascade_groups: the caller gets a deep copy")

    local one = emojis.cascade_groups("status")
    eq(#one, 1, "cascade_groups: a named set yields exactly one group")
    eq(one[1][1], "🔴", "cascade_groups: ... the right one")
    eq(#emojis.cascade_groups("nosuchset"), 0, "cascade_groups: an unknown set yields nothing")
  end

  -- ------------------------------------------- checkbox_target: cursor line
  do
    local buf = boxes()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    emojis.toggle()
    eq(lines_of(buf), "🔲 a|✅ b|🔲 c|🔲 d", "toggle: the cursor line only")

    emojis.toggle(nil, -1)
    eq(lines_of(buf), "🔲 a|🔲 b|🔲 c|🔲 d", "toggle: dir = -1 steps back")

    emojis.toggle("status")
    eq(lines_of(buf), "🔲 a|🔲 b|🔲 c|🔲 d", "toggle: a named set ignores a line from another set")

    emojis.checkbox_remove()
    eq(lines_of(buf), "🔲 a|b|🔲 c|🔲 d", "checkbox_remove: the cursor line only")
    emojis.checkbox_add()
    eq(lines_of(buf), "🔲 a|🔲 b|🔲 c|🔲 d", "checkbox_add: puts one back")
  end

  -- ------------------------------------------ checkbox_target: a count > 1
  -- In normal mode with a count, the target extends over the next `count`
  -- lines -- reusing the explicit-range path, so the buffer-bounds clamping
  -- stays in scope.resolve.
  do
    vim.keymap.set({ "n", "x" }, "<F8>", function()
      emojis.toggle()
    end, { desc = "emojis test: toggle" })

    local buf = boxes()
    feed("2<F8>")
    eq(lines_of(buf), "✅ a|✅ b|🔲 c|🔲 d", "toggle: a count extends to the next `count` lines")

    -- A count past the end of the buffer clamps instead of raising.
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    feed("9<F8>")
    eq(lines_of(buf), "✅ a|✅ b|✅ c|✅ d", "toggle: a count past the last line is clamped")
  end

  -- --------------------------------------------------------- pinned bug
  -- BUG: the visual branch reads the `'<`/`'>` marks, which Neovim only sets
  -- when the Visual area is LEFT. A mapping invoked from visual mode -- which
  -- is how the shipped preset binds this action (mode `{ "n", "x" }`) -- runs
  -- before that happens, so the marks still describe the PREVIOUS selection:
  --
  --   * in a buffer with no earlier selection, the action refuses outright
  --     ("no previous visual selection"), i.e. the documented "over a
  --     selection ticks a whole block" never works on first use;
  --   * once any selection has been made, a new one silently edits the lines
  --     of the OLD one -- lines the user did not select.
  --
  -- `vim.fn.getpos("v")` + the cursor (or a `<C-u>`-style mapping that leaves
  -- visual mode first) is what would read the live selection instead.
  do
    -- The marks are buffer-local, so a fresh buffer is a user's first
    -- selection in that file.
    local first = boxes()
    local said = H.notices(function()
      feed("Vj<F8>")
    end)
    feed("<Esc>")
    eq(lines_of(first), "🔲 a|🔲 b|🔲 c|🔲 d", "BUG(visual): a first selection toggles nothing")
    eq(said.error[1], "scope error: no previous visual selection", "BUG(visual): ... it refuses instead")

    -- Second buffer: leave a selection behind on lines 3-4 (that is what sets
    -- the marks), then select 1-2 and fire from inside the new selection.
    local stale = boxes()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    feed("Vj<Esc>")
    eq(vim.fn.getpos("'<")[2] .. "-" .. vim.fn.getpos("'>")[2], "3-4", "BUG(visual): the marks describe the finished selection")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    feed("Vj<F8>")
    feed("<Esc>")
    eq(lines_of(stale), "🔲 a|🔲 b|✅ c|✅ d", "BUG(visual): the previous selection is toggled, not the current one")

    vim.keymap.del({ "n", "x" }, "<F8>")
  end

  -- The other half of the same picture: called from normal mode -- after a
  -- selection has been left, marks and all -- the API takes the cursor-line
  -- branch and ignores those marks. So the visual branch is only ever entered
  -- in the one state where the marks are stale, which is what makes the defect
  -- above a dead end rather than an edge case.
  --
  -- The command form is unaffected: `:'<,'>Emojis toggle` arrives as an
  -- explicit Vim range, which `scope.resolve` honours before any scope
  -- keyword. That is the working way to tick a whole block today.
  do
    local buf = boxes()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    feed("Vj<Esc>")

    emojis.checkbox_remove()
    eq(lines_of(buf), "🔲 a|🔲 b|c|🔲 d", "API in normal mode: the cursor line, not the completed selection")

    vim.cmd("'<,'>Emojis toggle")
    eq(lines_of(buf), "🔲 a|✅ b|c|🔲 d", "range command: acts on the completed selection's lines")
  end

  config.setup({})
end
