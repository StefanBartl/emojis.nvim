---@module 'emojis.config'
---@brief Runtime configuration store for emojis.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active config
--- via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("emojis.config.DEFAULTS")

local M = {}

---@type Emojis.Config|nil
local _active = nil

---@type string[]  Scopes accepted as `default_scope`
local VALID_SCOPES = { "word", "line", "visual", "%", "cwd" }

---@param value any
---@param allowed any[]
---@return boolean
local function is_one_of(value, allowed)
  for i = 1, #allowed do
    if allowed[i] == value then return true end
  end
  return false
end

---Merge user options over the defaults and store the result.
---@param user_opts? Emojis.Config|table
---@return Emojis.Config
function M.setup(user_opts)
  if type(user_opts) ~= "table" then
    user_opts = {}
  end

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user_opts)

  if not is_one_of(merged.default_scope, VALID_SCOPES) then
    vim.notify(
      ("[emojis] invalid default_scope %q, using '%%'"):format(tostring(merged.default_scope)),
      vim.log.levels.WARN
    )
    merged.default_scope = "%"
  end

  _active = merged
  return _active
end

---@return Emojis.Config
function M.get()
  if _active == nil then
    _active = vim.deepcopy(DEFAULTS)
  end
  return _active
end

return M
