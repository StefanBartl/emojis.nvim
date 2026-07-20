-- docs/TESTS/overlay_spec.lua — quick-insert overlay: layout, navigation,
-- mode validation and frecency ordering.
--
-- The frecency store is redirected to a temp file by run.lua, so recording a
-- use here never touches the developer's real history.

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("emojis.config")
  local overlay = require("emojis.overlay")
  local frecency = require("emojis.overlay.frecency")

  local PICKS = {
    { "✅", "white_check_mark" },
    { "❌", "x" },
    { "⚠️", "warning" },
    { "🐛", "bug" },
    { "🔥", "fire" },
    { "🚀", "rocket" },
  }

  config.setup({ overlay = { picks = PICKS, columns = 3, limit = 6 } })
  frecency.reset()

  -- ---------------------------------------------------------------- frecency
  eq(frecency.sort(PICKS)[1][1], "✅", "frecency: curated order holds with no usage")

  frecency.record("🚀")
  frecency.record("🚀")
  eq(frecency.sort(PICKS)[1][1], "🚀", "frecency: a used glyph sorts first")
  eq(frecency.sort(PICKS)[2][1], "✅", "frecency: unused entries keep curated order")
  eq(#frecency.sort(PICKS), #PICKS, "frecency: sorting never adds or drops entries")

  frecency.reset()
  eq(frecency.sort(PICKS)[1][1], "✅", "frecency: reset clears recorded usage")

  -- -------------------------------------------------------- config validation
  config.setup({ overlay = { mode = "nonsense" } })
  eq(config.get().overlay.mode, "grid", "config: an invalid overlay.mode falls back to grid")

  config.setup({ overlay = { columns = 0 } })
  eq(config.get().overlay.columns, 5, "config: a non-positive overlay.columns falls back to 5")

  -- A user list shorter than the default must replace it, not merge into it.
  config.setup({ overlay = { picks = { { "🔥", "fire" } } } })
  eq(#config.get().overlay.picks, 1, "config: user overlay.picks replaces the default wholesale")

  -- ------------------------------------------------------------------ layout
  config.setup({ overlay = { picks = PICKS, columns = 3, limit = 6, frecency = false } })

  local target = H.scratch()
  vim.api.nvim_buf_set_lines(target, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  overlay.open("grid")
  ok(overlay.is_open(), "grid: overlay opens")

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  eq(#lines, 2, "grid: 6 picks across 3 columns render as 2 rows")
  ok(lines[1]:find("✅", 1, true) ~= nil, "grid: first row holds the first pick")
  ok(lines[1]:find("🚀", 1, true) == nil, "grid: the fourth pick wrapped to row 2")

  overlay.close()
  eq(overlay.is_open(), false, "grid: close() closes the overlay")

  -- ------------------------------------------------------- invalid open mode
  overlay.open("nonsense")
  eq(overlay.is_open(), false, "open: an unknown mode opens nothing")

  -- ----------------------------------------------------- hotkey labels render
  overlay.open("grid_keys")
  ok(overlay.is_open(), "grid_keys: overlay opens")
  local keyed = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  ok(keyed[1]:find("a", 1, true) ~= nil, "grid_keys: cells carry hotkey labels")
  overlay.close()

  -- Re-opening must not strand the previous float.
  overlay.open("grid")
  local first_win = vim.api.nvim_get_current_win()
  overlay.open("grid")
  ok(vim.api.nvim_win_is_valid(first_win) == false, "open: re-opening closes the previous overlay")
  overlay.close()

  config.setup({})
  frecency.reset()
end
