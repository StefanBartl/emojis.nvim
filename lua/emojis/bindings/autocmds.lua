---@module 'emojis.bindings.autocmds'
--- No autocommands — kept as an empty module for structural symmetry.
---
--- emojis.nvim deliberately has no autocmd-driven behaviour (e.g. no
--- auto-clear on save) — a deliberate decision, not an omission. This stub
--- exists so `bindings/` mirrors the usrcmds/keymaps/autocmds shape used
--- across the other plugins.

local M = {}

---@param _cfg Emojis.Config
---@return nil
function M.setup(_cfg) end

return M
