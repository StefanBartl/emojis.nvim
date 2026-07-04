---@module 'emojis.bindings'
---@brief Orchestrates emojis.nvim's bindings: usrcmds, keymaps, autocmds.
---@description
--- Always registers the `:Emojis` command. When `keymaps.preset` is enabled
--- it also binds the preset keymaps and labels the `<leader>e` group in
--- which-key (no-op if not installed).

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Emojis.Config
---@return nil
function M.setup(cfg)
  require("emojis.bindings.usrcmds").setup(cfg)

  if cfg.keymaps and cfg.keymaps.preset then
    require("emojis.bindings.keymaps").bind_preset()
    require("emojis.bindings.which_key").setup()
  end

  require("emojis.bindings.autocmds").setup(cfg)
end

return M
