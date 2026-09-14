-- TESTS/picker_spec.lua — insert picker: engine selection + fallback.
-- telescope.nvim/fzf-lua are not on rtp in this headless harness, so "auto"
-- always reaches select_fallback here.
--
-- Two fallback paths, both exercised with `vim.ui.select` replaced as a test
-- double (restored right after each case):
--   1. ui.nvim IS on rtp in this harness (CI checks it out as a sibling): with
--      `respect_override = true`, ui.kit.select detects the stubbed
--      `vim.ui.select` as a foreign override and delegates straight to it.
--   2. ui.kit itself unavailable (stubbed via package.preload so `require`
--      fails, simulating ui.nvim not being installed at all) — the actual
--      regression this spec guards: `select_fallback` must catch that and
--      fall through to plain `vim.ui.select`, not error.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq = H.eq
  local picker = require("emojis.picker")
  local config = require("emojis.config")

  config.setup({ picks = { { "🚀", "rocket" }, { "🔥", "fire" } } })

  local buf = H.scratch()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- between "a" and "b"

  local orig_select = vim.ui.select

  -- Case 1: ui.kit present, respect_override delegates to the stubbed vim.ui.select.
  vim.ui.select = function(items, _, on_choice)
    eq(#items, 2, "select fallback (ui.kit present): receives the configured picks")
    on_choice(items[1], 1)
  end
  picker.insert()
  vim.ui.select = orig_select
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "a🚀b", "insert: glyph inserted via ui.kit's respect_override delegation")

  -- Case 2: ui.kit unavailable -- require("ui.kit") must fail without taking
  -- select_fallback down with it, landing on plain vim.ui.select instead.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })

  local orig_loaded = package.loaded["ui.kit"]
  local orig_preload = package.preload["ui.kit"]
  package.loaded["ui.kit"] = nil
  package.preload["ui.kit"] = function()
    error("ui.kit not installed (test stub)")
  end

  vim.ui.select = function(items, _, on_choice)
    eq(#items, 2, "select fallback (ui.kit absent): receives the configured picks")
    on_choice(items[2], 2)
  end
  picker.insert()
  vim.ui.select = orig_select
  package.loaded["ui.kit"] = orig_loaded
  package.preload["ui.kit"] = orig_preload

  eq(
    vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1],
    "a🔥b",
    "insert: ui.kit require failure degrades to plain vim.ui.select instead of erroring"
  )

  config.setup({})
end
