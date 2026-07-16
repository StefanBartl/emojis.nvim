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
    info = function(msg)
      vim.notify(PREFIX .. msg, vim.log.levels.INFO)
    end,
    warn = function(msg)
      vim.notify(PREFIX .. msg, vim.log.levels.WARN)
    end,
    error = function(msg)
      vim.notify(PREFIX .. msg, vim.log.levels.ERROR)
    end,
    debug = function(msg)
      vim.notify(PREFIX .. msg, vim.log.levels.DEBUG)
    end,
  }
  return _notifier
end

---Deduplicate a list, preserving first-occurrence order. Uses
---`lib.lua.tables.dedup_list` if available, else a local fallback.
---@param list any[]
---@return any[]
function M.dedup_list(list)
  local lib_tables = try_require("lib.lua.tables")
  if lib_tables and type(lib_tables.dedup_list) == "function" then
    local ok, result = pcall(lib_tables.dedup_list, list)
    if ok then
      return result
    end
  end

  local seen, out = {}, {}
  for _, v in ipairs(list) do
    if not seen[v] then
      seen[v] = true
      out[#out + 1] = v
    end
  end
  return out
end

---Decode the UTF-8 codepoint starting at byte index `i` (1-based) of `str`.
---Uses `lib.lua.strings.utf8.decode` if available, else a local fallback
---(only the 3/4-byte lead-byte cases — sufficient for emoji glyphs).
---@param str string
---@param i? integer
---@return integer|nil cp
function M.utf8_decode(str, i)
  local lib_utf8 = try_require("lib.lua.strings.utf8")
  if lib_utf8 and type(lib_utf8.decode) == "function" then
    local ok, cp = pcall(lib_utf8.decode, str, i)
    if ok then
      return cp
    end
  end

  i = i or 1
  local b1 = str:byte(i) or 0
  if b1 >= 0xF0 and #str >= i + 3 then
    local b2, b3, b4 = str:byte(i + 1), str:byte(i + 2), str:byte(i + 3)
    return ((b1 - 0xF0) * 0x40000) + ((b2 - 0x80) * 0x1000) + ((b3 - 0x80) * 0x40) + (b4 - 0x80)
  elseif b1 >= 0xE0 and #str >= i + 2 then
    local b2, b3 = str:byte(i + 1), str:byte(i + 2)
    return ((b1 - 0xE0) * 0x1000) + ((b2 - 0x80) * 0x40) + (b3 - 0x80)
  end
  return b1
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
