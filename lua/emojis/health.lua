---@module 'emojis.health'
---@brief :checkhealth emojis provider.

local M = {}

---@return nil
function M.check()
  vim.health.start("emojis")

  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ recommended")
  end

  if type(vim.ui) == "table" and type(vim.ui.select) == "function" then
    vim.health.ok("vim.ui.select is available (insert picker)")
  else
    vim.health.warn("vim.ui.select unavailable — :Emojis insert will not work")
  end

  local cmd = require("emojis.config").get().search.cmd
  if vim.fn.executable(cmd) == 1 then
    vim.health.ok(("'%s' found on PATH (cwd scope)"):format(cmd))
  else
    vim.health.warn(("'%s' not found — :Emojis list/count cwd will not work"):format(cmd))
  end

  if type(vim.system) == "function" then
    vim.health.ok("vim.system available (async cwd search)")
  else
    vim.health.info("vim.system missing — falling back to jobstart for cwd search")
  end

  if vim.g.loaded_emojis then
    vim.health.ok("plugin loaded (vim.g.loaded_emojis = " .. tostring(vim.g.loaded_emojis) .. ")")
  else
    vim.health.warn("plugin guard not set — call require('emojis').setup()")
  end

  if require("emojis.bindings.which_key").available() then
    vim.health.ok("which-key found (preset keymaps get labeled group)")
  else
    vim.health.info("which-key not installed (optional; only labels the preset's <leader>e group)")
  end

  if require("emojis.config").get().keymaps.preset then
    vim.health.ok("keymaps.preset enabled (<C-e>, <leader>ec, <leader>el bound)")
  else
    vim.health.info("keymaps.preset disabled (default) — set keymaps.preset = true to opt in")
  end
end

return M
