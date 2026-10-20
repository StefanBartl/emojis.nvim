---@module 'emojis.config'
--- Runtime configuration store for emojis.nvim.
---
--- Merges user options over the immutable DEFAULTS and exposes the active config
--- via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("emojis.config.DEFAULTS")
local notify = require("emojis.util.notify")

local M = {}

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

--- To the schema that `lib.lua.config` infers from `DEFAULTS`, the options are open: the checks are
--- `sanitize_level` before the merge and the ERR-22 block in the resolve hook after it. An unknown
--- top-level key is caught there as well.
local ANY = "boolean|number|string|table|function"
---@type table<string, string>
local SCHEMA = {}
for _, key in ipairs(TOP_LEVEL_OPTS) do
  SCHEMA[key] = ANY
end

local cfg = require("lib.lua.config").new(DEFAULTS, {
  name = "emojis",
  schema = SCHEMA,
  -- ERR-50: unknown-key validation runs before the merge, so a typo in a nested option is dropped
  -- with a warning instead of vanishing into the result next to the real key it shadows. `opts` is
  -- a private copy, so it is rewritten in place.
  normalize = function(opts)
    local sanitized = sanitize_level(opts, TOP_LEVEL_OPTS, "")
    for key in pairs(opts) do
      opts[key] = nil
    end
    for key, value in pairs(sanitized) do
      opts[key] = value
    end
  end,
  -- After the merge. (A user list shorter than the default replaces it wholesale, a curated set
  -- like "these five glyphs" or one checkbox cycle must mean exactly what was given: the merge
  -- of lib.lua.config does that for every list.)
  resolve = function(current)
    -- ERR-22: a `default_set` that names no usable set would make every
    -- argument-less `:Emojis toggle` fail at use time, with setup() silent;
    -- degrade to "search every set" instead and say why.
    do
      local default_set = current.checkbox.default_set
      if default_set ~= "" then
        local set = type(default_set) == "string" and current.checkbox.sets[default_set] or nil
        if type(set) ~= "table" or #set == 0 then
          notify.warn(("invalid checkbox.default_set %s, searching every set"):format(vim.inspect(default_set)))
          current.checkbox.default_set = ""
        end
      end
    end

    if not is_one_of(current.overlay.mode, VALID_OVERLAY_MODES) then
      notify.warn(("invalid overlay.mode %q, using 'grid'"):format(tostring(current.overlay.mode)))
      current.overlay.mode = "grid"
    end

    if type(current.overlay.columns) ~= "number" or current.overlay.columns < 1 then
      notify.warn("invalid overlay.columns, using 5")
      current.overlay.columns = 5
    end

    if not is_one_of(current.default_scope, VALID_SCOPES) then
      notify.warn(("invalid default_scope %q, using '%%'"):format(tostring(current.default_scope)))
      current.default_scope = "%"
    end

    -- ERR-22: the remaining scalars degrade to their default on an invalid
    -- type/value too, instead of reaching overlay/init.lua's `math.min()` or
    -- actions.lua's `vim.defer_fn()` with something that raises there instead,
    -- at use time, on every call, with `setup()` itself reporting nothing.
    if type(current.overlay.limit) ~= "number" or current.overlay.limit < 1 then
      notify.warn(("invalid overlay.limit %s, using %d"):format(vim.inspect(current.overlay.limit), DEFAULTS.overlay.limit))
      current.overlay.limit = DEFAULTS.overlay.limit
    end

    if type(current.preview.duration_ms) ~= "number" or current.preview.duration_ms < 0 then
      notify.warn(
        ("invalid preview.duration_ms %s, using %d"):format(
          vim.inspect(current.preview.duration_ms),
          DEFAULTS.preview.duration_ms
        )
      )
      current.preview.duration_ms = DEFAULTS.preview.duration_ms
    end

    if type(current.preview.hl_group) ~= "string" or current.preview.hl_group == "" then
      notify.warn(
        ("invalid preview.hl_group %s, using %q"):format(vim.inspect(current.preview.hl_group), DEFAULTS.preview.hl_group)
      )
      current.preview.hl_group = DEFAULTS.preview.hl_group
    end

    if type(current.wrap.prefix) ~= "string" then
      notify.warn(("invalid wrap.prefix %s, using %q"):format(vim.inspect(current.wrap.prefix), DEFAULTS.wrap.prefix))
      current.wrap.prefix = DEFAULTS.wrap.prefix
    end
    if type(current.wrap.suffix) ~= "string" then
      notify.warn(("invalid wrap.suffix %s, using %q"):format(vim.inspect(current.wrap.suffix), DEFAULTS.wrap.suffix))
      current.wrap.suffix = DEFAULTS.wrap.suffix
    end

    if type(current.search.extra_args) ~= "table" then
      notify.warn(("invalid search.extra_args %s, using the defaults"):format(vim.inspect(current.search.extra_args)))
      current.search.extra_args = vim.deepcopy(DEFAULTS.search.extra_args)
    end

    -- search.cmd reaches `vim.fn.executable()` and `vim.system()` in search.lua
    -- unchecked otherwise -- a non-string (e.g. a stray number) raises
    -- `E1174: String required for argument 1` from both, at search time rather
    -- than at setup(), and an empty string passes the same way through to a
    -- confusing "'' not found on PATH" instead of just using ripgrep.
    if type(current.search.cmd) ~= "string" or current.search.cmd == "" then
      notify.warn(("invalid search.cmd %s, using %q"):format(vim.inspect(current.search.cmd), DEFAULTS.search.cmd))
      current.search.cmd = DEFAULTS.search.cmd
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
    if type(current.command) ~= "string" or not current.command:match("^%u%w*$") then
      notify.warn(("invalid command %s, using %q"):format(vim.inspect(current.command), DEFAULTS.command))
      current.command = DEFAULTS.command
    end
  end,
})

---Merge user options over the defaults and store the result. Every call
---starts from `DEFAULTS`.
---@param user_opts? Emojis.Opts
---@return Emojis.Config
function M.setup(user_opts)
  cfg.setup(type(user_opts) == "table" and user_opts or nil)
  return cfg.get()
end

---@return Emojis.Config
function M.get()
  return cfg.get()
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
