---@module 'emojis.config'
---@brief Runtime configuration store for emojis.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active config
--- via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("emojis.config.DEFAULTS")
local notify = require("emojis.util.notify")

local M = {}

---@type Emojis.Config|nil
local _active = nil

---@type string[]  Scopes accepted as `default_scope`
local VALID_SCOPES = { "word", "line", "visual", "%", "cwd" }

---@type string[]  Accepted `overlay.mode` values
local VALID_OVERLAY_MODES = { "grid", "grid_keys", "list" }

---@param value any
---@param allowed any[]
---@return boolean
local function is_one_of(value, allowed)
  for i = 1, #allowed do
    if allowed[i] == value then
      return true
    end
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

  -- tbl_deep_extend merges lists index-wise, so a user list shorter than the
  -- default would keep the default's tail. For a curated set that is wrong:
  -- "these five glyphs" must mean exactly five. Replace it wholesale instead.
  if type(user_opts.overlay) == "table" and type(user_opts.overlay.picks) == "table" then
    merged.overlay.picks = vim.deepcopy(user_opts.overlay.picks)
  end

  -- Same index-wise merge problem, for each individual checkbox cycle: a user
  -- redefining `checkbox = { "🔲", "✅", "❌" }` must get exactly those three
  -- states, not their three merged over the default's two.
  if type(user_opts.checkbox) == "table" and type(user_opts.checkbox.sets) == "table" then
    for name, set in pairs(user_opts.checkbox.sets) do
      if type(set) == "table" then
        merged.checkbox.sets[name] = vim.deepcopy(set)
      end
    end
  end
  if type(user_opts.checkbox) == "table" and type(user_opts.checkbox.order) == "table" then
    merged.checkbox.order = vim.deepcopy(user_opts.checkbox.order)
  end

  if not is_one_of(merged.overlay.mode, VALID_OVERLAY_MODES) then
    notify.warn(("invalid overlay.mode %q, using 'grid'"):format(tostring(merged.overlay.mode)))
    merged.overlay.mode = "grid"
  end

  if type(merged.overlay.columns) ~= "number" or merged.overlay.columns < 1 then
    notify.warn("invalid overlay.columns, using 5")
    merged.overlay.columns = 5
  end

  if not is_one_of(merged.default_scope, VALID_SCOPES) then
    notify.warn(("invalid default_scope %q, using '%%'"):format(tostring(merged.default_scope)))
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

---Resolve a checkbox set name into the ordered list of cycles to search.
---
---`name` nil/"" means "every set", ordered by `checkbox.order` first so
---ambiguity resolution is under the user's control; sets absent from `order`
---follow, name-sorted, so a newly added set is never silently unreachable.
---A named set returns just that one — an explicit `:Emojis toggle status`
---should cycle the status glyphs even if another set also claims one.
---@param name? string
---@return string[][] sets, string|nil err
function M.checkbox_sets(name)
  local cb = M.get().checkbox

  if name ~= nil and name ~= "" then
    local set = cb.sets[name]
    if type(set) ~= "table" or #set == 0 then
      return {}, ("unknown checkbox set %q"):format(name)
    end
    return { set }, nil
  end

  local out, seen = {}, {}
  for i = 1, #cb.order do
    local key = cb.order[i]
    local set = cb.sets[key]
    if type(set) == "table" and #set > 0 and not seen[key] then
      seen[key] = true
      out[#out + 1] = set
    end
  end

  local rest = {}
  for key in pairs(cb.sets) do
    if not seen[key] then
      rest[#rest + 1] = key
    end
  end
  table.sort(rest)
  for i = 1, #rest do
    local set = cb.sets[rest[i]]
    if type(set) == "table" and #set > 0 then
      out[#out + 1] = set
    end
  end

  return out, nil
end

---Names of the configured checkbox sets, for command completion.
---@return string[]
function M.checkbox_set_names()
  local names = {}
  for key in pairs(M.get().checkbox.sets) do
    names[#names + 1] = key
  end
  table.sort(names)
  return names
end

return M
