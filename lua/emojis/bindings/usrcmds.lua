---@module 'emojis.bindings.usrcmds'
---@brief The `:Emojis` user command (always defined).
---@description
--- Thin wrapper so the whole binding surface (usrcmds/keymaps/autocmds) lives
--- under `bindings/`. Parsing, validation, and dispatch stay in
--- `emojis.commands` — this module only registers it.

local M = {}

---@param cfg Emojis.Config
---@return nil
function M.setup(cfg)
  require("emojis.commands").register(cfg)
end

return M
