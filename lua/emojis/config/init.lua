---@module 'emojis.config'
--- Runtime configuration store for emojis.nvim.
---
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
---@internal
local function is_one_of(value, allowed)
  for i = 1, #allowed do
    if allowed[i] == value then
      return true
    end
  end
  return false
end

---@type string[]  Top-level `Emojis.Opts` keys `setup()` accepts.
local TOP_LEVEL_OPTS = {
  "default_scope",
  "command",
  "picks",
  "names",
  "search",
  "keymaps",
  "wrap",
  "preview",
  "picker",
  "overlay",
  "checkbox",
}

-- Sub-tables merged wholesale via `vim.tbl_deep_extend` below would otherwise
-- absorb a typo'd nested key silently -- ERR-50 requires the check to run
-- before that merge, not after. `overlay.picks`/`checkbox.sets`/`checkbox.order`
-- hold user *data* (glyph entries, set names), not named options, so they are
-- deliberately absent here and pass through unvalidated. `keymaps` is absent
-- for a related reason: its accepted keys are not this module's own DEFAULTS
-- shape (`preset` plus the per-action names `insert`/`overlay`/`toggle`/
-- `count`/`list` declared in bindings/keymaps.lua's spec) -- a static list
-- here would either reject the documented per-action overrides or drift the
-- moment an action is renamed. `lib.nvim.bindings.keymap.registry.register`
-- already validates against the live action registry (its own did-you-mean
-- included) before binding, so `keymaps` passes through here unvalidated and
-- is checked once, in the one place that actually knows the valid keys.
---@type table<string, string[]>
local NESTED_OPTS = {
  search = { "cmd", "extra_args", "no_ignore" },
  wrap = { "prefix", "suffix" },
  preview = { "enable", "duration_ms", "hl_group" },
  picker = { "engine" },
  overlay = { "mode", "picks", "frecency", "columns", "limit", "title", "theme" },
  checkbox = { "default_set", "sets", "order" },
}

---Nearest allowed key within edit distance 3, as a " (did you mean %q?)" hint.
---@param name string
---@param allowed string[]
---@return string
---@internal
local function did_you_mean(name, allowed)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local best, best_distance = nil, nil
  for _, known in ipairs(allowed) do
    local d = levenshtein(name, known)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = known, d
    end
  end
  return best and (" (did you mean %q?)"):format(best) or ""
end

---Drop (and warn about) every key not in `allowed`, recursing into the
---sub-tables named in NESTED_OPTS so a typo cannot hide behind
---`vim.tbl_deep_extend` either. Returns a shallow copy; kept leaf values are
---the original references, not deep-copied.
---@param raw table
---@param allowed string[]
---@param path string  dotted prefix for a nested warning, e.g. "overlay."
---@return table
---@internal
local function sanitize_level(raw, allowed, path)
  local known = {}
  for _, k in ipairs(allowed) do
    known[k] = true
  end

  local out = {}
  for key, value in pairs(raw) do
    if type(key) ~= "string" then
      out[key] = value -- not a named option (e.g. a list entry); nothing to validate
    elseif not known[key] then
      notify.warn(("unknown config key %q%s -- ignored"):format(path .. key, did_you_mean(key, allowed)))
    elseif type(value) == "table" and NESTED_OPTS[path .. key] then
      out[key] = sanitize_level(value, NESTED_OPTS[path .. key], path .. key .. ".")
    else
      out[key] = value
    end
  end
  return out
end

---Merge user options over the defaults and store the result.
---@param user_opts? Emojis.Opts
---@return Emojis.Config
function M.setup(user_opts)
  if type(user_opts) ~= "table" then
    user_opts = {}
  end

  -- ERR-50: unknown-key validation runs before the merge below, so a typo in
  -- a nested option is dropped with a warning instead of vanishing silently
  -- into `tbl_deep_extend`'s result, sitting next to the real key it shadows.
  local sanitized = sanitize_level(user_opts, TOP_LEVEL_OPTS, "")

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), sanitized)

  -- tbl_deep_extend merges lists index-wise, so a user list shorter than the
  -- default would keep the default's tail. For a curated set that is wrong:
  -- "these five glyphs" must mean exactly five. Replace it wholesale instead.
  local user_picks = sanitized.overlay and sanitized.overlay.picks
  if type(user_picks) == "table" then
    merged.overlay.picks = vim.deepcopy(user_picks)
  end

  -- Same index-wise merge problem, for each individual checkbox cycle: a user
  -- redefining `checkbox = { "🔲", "✅", "❌" }` must get exactly those three
  -- states, not their three merged over the default's two.
  if type(sanitized.checkbox) == "table" and type(sanitized.checkbox.sets) == "table" then
    for name, set in pairs(sanitized.checkbox.sets) do
      if type(set) == "table" then
        merged.checkbox.sets[name] = vim.deepcopy(set)
      end
    end
  end
  local user_order = sanitized.checkbox and sanitized.checkbox.order
  if type(user_order) == "table" then
    merged.checkbox.order = vim.deepcopy(user_order)
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

  -- ERR-22: the remaining scalars degrade to their default on an invalid
  -- type/value too, instead of reaching overlay/init.lua's `math.min()` or
  -- actions.lua's `vim.defer_fn()` with something that raises there instead,
  -- at use time, on every call, with `setup()` itself reporting nothing.
  if type(merged.overlay.limit) ~= "number" or merged.overlay.limit < 1 then
    notify.warn(("invalid overlay.limit %s, using %d"):format(vim.inspect(merged.overlay.limit), DEFAULTS.overlay.limit))
    merged.overlay.limit = DEFAULTS.overlay.limit
  end

  if type(merged.preview.duration_ms) ~= "number" or merged.preview.duration_ms < 0 then
    notify.warn(
      ("invalid preview.duration_ms %s, using %d"):format(vim.inspect(merged.preview.duration_ms), DEFAULTS.preview.duration_ms)
    )
    merged.preview.duration_ms = DEFAULTS.preview.duration_ms
  end

  if type(merged.preview.hl_group) ~= "string" or merged.preview.hl_group == "" then
    notify.warn(("invalid preview.hl_group %s, using %q"):format(vim.inspect(merged.preview.hl_group), DEFAULTS.preview.hl_group))
    merged.preview.hl_group = DEFAULTS.preview.hl_group
  end

  if type(merged.wrap.prefix) ~= "string" then
    notify.warn(("invalid wrap.prefix %s, using %q"):format(vim.inspect(merged.wrap.prefix), DEFAULTS.wrap.prefix))
    merged.wrap.prefix = DEFAULTS.wrap.prefix
  end
  if type(merged.wrap.suffix) ~= "string" then
    notify.warn(("invalid wrap.suffix %s, using %q"):format(vim.inspect(merged.wrap.suffix), DEFAULTS.wrap.suffix))
    merged.wrap.suffix = DEFAULTS.wrap.suffix
  end

  if type(merged.search.extra_args) ~= "table" then
    notify.warn(("invalid search.extra_args %s, using the defaults"):format(vim.inspect(merged.search.extra_args)))
    merged.search.extra_args = vim.deepcopy(DEFAULTS.search.extra_args)
  end

  -- search.cmd reaches `vim.fn.executable()` and `vim.system()` in search.lua
  -- unchecked otherwise -- a non-string (e.g. a stray number) raises
  -- `E1174: String required for argument 1` from both, at search time rather
  -- than at setup(), and an empty string passes the same way through to a
  -- confusing "'' not found on PATH" instead of just using ripgrep.
  if type(merged.search.cmd) ~= "string" or merged.search.cmd == "" then
    notify.warn(("invalid search.cmd %s, using %q"):format(vim.inspect(merged.search.cmd), DEFAULTS.search.cmd))
    merged.search.cmd = DEFAULTS.search.cmd
  end

  -- `command` names the `:Emojis` user command via
  -- `lib.nvim.bindings.usercmd.composer.verb`, whose own `assert(type(name)
  -- == "string" and name ~= "", ...)` raises a hard Lua error out of
  -- `bindings/init.lua` -> `commands.register()` on setup itself for anything
  -- else, taking the whole plugin down with it instead of degrading.
  --
  -- A non-empty string is not enough by itself, though: `composer.verb` only
  -- asserts non-empty before handing `name` straight to
  -- `vim.api.nvim_create_user_command()`, which enforces its own ex-command
  -- grammar (first character an uppercase ASCII letter, the rest alphanumeric)
  -- and raises just as hard -- uncaught -- for anything that violates it, e.g.
  -- `command = "emojis2"` or `"Emo-jis"`. That is the exact same crash this
  -- fix exists to prevent, reached through a sibling check instead of
  -- composer's own, so the pattern below matches nvim's grammar rather than
  -- merely "is a string".
  if type(merged.command) ~= "string" or not merged.command:match("^%u%w*$") then
    notify.warn(("invalid command %s, using %q"):format(vim.inspect(merged.command), DEFAULTS.command))
    merged.command = DEFAULTS.command
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
