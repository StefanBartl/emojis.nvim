-- docs/TESTS/picker_spec.lua — insert picker: engine selection + fallback.
-- telescope.nvim/fzf-lua are not on rtp in this headless harness, so "auto"
-- must gracefully fall back to vim.ui.select without erroring.

return function(H)
  local eq = H.eq
  local picker = require("emojis.picker")
  local config = require("emojis.config")

  config.setup({ picks = { { "🚀", "rocket" }, { "🔥", "fire" } } })

  local buf = H.scratch()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- between "a" and "b"

  local orig_select = vim.ui.select
  vim.ui.select = function(items, _, on_choice)
    eq(#items, 2, "select fallback: receives the configured picks")
    on_choice(items[1], 1)
  end

  picker.insert()
  vim.ui.select = orig_select

  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "a🚀b", "insert: glyph inserted at cursor via fallback")

  config.setup({})
end
