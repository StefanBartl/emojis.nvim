-- docs/TESTS/commands_spec.lua — :Emojis exists; keymaps.preset gates the preset keys.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq

  package.loaded["emojis"] = nil
  package.loaded["emojis.config"] = nil
  local emojis = require("emojis")

  emojis.setup({})
  eq(vim.fn.exists(":Emojis"), 2, ":Emojis defined")

  -- preset keymaps are opt-in and off by default
  eq(vim.fn.maparg("<C-e>", "n"), "", "preset off by default: <C-e> unbound")

  -- enabling the preset binds it (setup() is idempotent, so bind directly
  -- through the bindings module to exercise the gate without a second setup())
  local cfg = require("emojis.config").setup({ keymaps = { preset = true } })
  require("emojis.bindings.keymaps").bind_preset()
  local mapping = vim.fn.maparg("<C-e>", "n")
  eq(mapping ~= "", true, "preset on: <C-e> bound")
  eq(cfg.keymaps.preset, true, "config reflects keymaps.preset = true")

  -- :Emojis unreplace restores :name: placeholders back to emojis
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "shipped :white_check_mark: today" })
    vim.cmd("Emojis unreplace %")
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    eq(line, "shipped ✅ today", "unreplace: :name: restored to emoji")
  end

  -- "word" scope only clears the whitespace-delimited token under the cursor
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep 🚀done here" })
    vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- inside "🚀done"
    vim.cmd("Emojis clear word")
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    eq(line, "keep done here", "word scope: only the cursor's token is cleared")
  end
end
