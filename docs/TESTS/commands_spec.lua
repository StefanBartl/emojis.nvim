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
end
