---@module 'emojis.util.lib'
---@brief Soft, guarded bridge to the optional `lib.nvim` helper library.
---@description
--- emojis.nvim prefers `lib.nvim.notify` / `lib.nvim.map` when present, but
--- must stay fully functional standalone. Every accessor here probes the
--- corresponding module with `pcall` and falls back to the native Neovim API.
--- No hard dependency is ever introduced.

local M = {}

---@param name string
---@return table|nil
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

---@type table|nil
local _notifier

---Prefixed notifier. Uses `lib.nvim.notify` if available, else `vim.notify`.
---@return table  { info, warn, error, debug }
function M.notifier()
  if _notifier then
    return _notifier
  end

  local lib_notify = try_require("lib.nvim.notify")
  if lib_notify and type(lib_notify.create) == "function" then
    local ok, notifier = pcall(lib_notify.create, "[emojis]")
    if ok and type(notifier) == "table" then
      _notifier = notifier
      return _notifier
    end
  end

  local PREFIX = "[emojis] "
  _notifier = {
    info  = function(msg) vim.notify(PREFIX .. msg, vim.log.levels.INFO) end,
    warn  = function(msg) vim.notify(PREFIX .. msg, vim.log.levels.WARN) end,
    error = function(msg) vim.notify(PREFIX .. msg, vim.log.levels.ERROR) end,
    debug = function(msg) vim.notify(PREFIX .. msg, vim.log.levels.DEBUG) end,
  }
  return _notifier
end

---Set a keymap. Uses `lib.nvim.map` if available, else `vim.keymap.set`.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts table|nil
---@return nil
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    local desc = opts.desc
    opts.desc = nil
    pcall(lib_map, mode, lhs, rhs, opts, desc)
    return
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
