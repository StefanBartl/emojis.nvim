---@module 'emojis.bindings'
--- Orchestrates emojis.nvim's bindings: usrcmds, keymaps, autocmds.
---
--- Always registers the `:Emojis` command and declares the preset's keymap
--- actions. Whether any of them are actually bound is the keymap registry's
--- decision, from `keymaps.preset` and the per-action overrides.

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Emojis.Config
---@return nil
function M.setup(cfg)
  require("emojis.bindings.usrcmds").setup(cfg)

  -- Called unconditionally, including with `keymaps.preset = false`: the
  -- registry honours `preset` itself, and binding nothing is not the same as
  -- declaring nothing -- :checkhealth and generated docs ask what EXISTS.
  -- The which-key group label moved into the keymap spec.
  require("emojis.bindings.keymaps").bind_preset(cfg)

  require("emojis.bindings.autocmds").setup(cfg)
end

return M
