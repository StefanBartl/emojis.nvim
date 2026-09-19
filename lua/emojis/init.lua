---@module 'emojis'
--- Public entry point for emojis.nvim.
---
--- Registers the `:Emojis [action] [scope]` command and exposes a small Lua API.
--- Idempotent — the first `setup()` wins.
---
--- Example: >lua
---   require("emojis").setup({ default_scope = "%" })
--- <

local M = {}

---@type boolean
local _done = false

---Configure and activate emojis.nvim.
---@param opts? Emojis.Opts
---@return nil
function M.setup(opts)
  if _done then
    return
  end
  _done = true

  local config = require("emojis.config")
  local cfg = config.setup(opts)

  require("emojis.bindings").setup(cfg)

  vim.g.loaded_emojis = 1
end

-- Public API ------------------------------------------------------------------

---Clear emojis from the whole current buffer.
---@return nil
function M.clear()
  local scope_m = require("emojis.core.scope")
  local target = scope_m.resolve("%", 0, 0, 0)
  if target then
    require("emojis.actions").edit("clear", target)
  end
end

---Open the insert picker at the cursor.
---@return nil
function M.insert()
  require("emojis.picker").insert()
end

---Open the quick-insert overlay.
---@param mode? Emojis.Config.Overlay.Mode  Defaults to `config.overlay.mode`
---@return nil
function M.overlay(mode)
  require("emojis.overlay").open(mode)
end

---Resolve the line range a checkbox action should act on: an explicit visual
---selection, else the cursor line -- or, in normal mode with a count > 1,
---the next `count` lines starting at the cursor.
---@return Emojis.Target|nil target, string|nil err
---@internal
local function checkbox_target()
  local scope_m = require("emojis.core.scope")
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Still *inside* the selection here: the preset binds these keys in `x`
    -- mode, so the callback runs before visual mode is left. `'<`/`'>` are only
    -- written on leaving it, so the "visual" scope read the *previous*
    -- selection -- it errored on the first selection in a buffer and silently
    -- toggled stale lines after that. `getpos("v")` is the anchor of the live
    -- selection and the cursor is its other end; feeding both through the
    -- explicit-range path keeps buffer-bounds clamping in scope.resolve, in
    -- the same one place the count > 1 branch below uses.
    local vwin = vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(vwin) then
      return nil, "current window is not valid"
    end
    local anchor = vim.fn.getpos("v")[2] -- 1-based row of the selection anchor
    local head = vim.api.nvim_win_get_cursor(vwin)[1]
    return scope_m.resolve("line", 2, math.min(anchor, head), math.max(anchor, head))
  end

  local count = vim.v.count1
  if count <= 1 then
    return scope_m.resolve("line", 0, 0, 0)
  end

  -- Normal mode with a count > 1: extend the target to the next `count`
  -- lines starting at the cursor. Reuses the explicit-range path (the same
  -- one `:10,20Emojis toggle` takes, see commands.lua) so buffer-bounds
  -- clamping stays in scope.resolve, in one place.
  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return nil, "current window is not valid"
  end
  local cur = vim.api.nvim_win_get_cursor(win)[1] -- 1-based
  return scope_m.resolve("line", 2, cur, cur + count - 1)
end

---Cycle the emoji checkbox on the cursor line (or the visual selection).
---@param set? string    Checkbox set name; nil/"" searches every set
---@param dir? integer   1 forward (default), -1 backward
---@return nil
function M.toggle(set, dir)
  local target, err = checkbox_target()
  if not target then
    require("emojis.util.notify").error("scope error: " .. tostring(err))
    return
  end
  require("emojis.actions").checkbox("toggle", target, set, dir)
end

---Add a checkbox to the cursor line (or the visual selection) if it lacks one.
---@param set? string
---@return nil
function M.checkbox_add(set)
  local target, err = checkbox_target()
  if not target then
    require("emojis.util.notify").error("scope error: " .. tostring(err))
    return
  end
  require("emojis.actions").checkbox("add", target, set)
end

---Remove the checkbox from the cursor line (or the visual selection).
---@param set? string
---@return nil
function M.checkbox_remove(set)
  local target, err = checkbox_target()
  if not target then
    require("emojis.util.notify").error("scope error: " .. tostring(err))
    return
  end
  require("emojis.actions").checkbox("remove", target, set)
end

---The configured checkbox cycles in cascade.nvim's `cycle.groups` format.
---
---The bridge between the two plugins: emojis.nvim owns the glyph vocabulary,
---cascade.nvim owns cursor-precise cycling (its `\k\+` tokenizer already
---matches emoji, since 'iskeyword' covers the lead bytes). Feeding the same
---sets to both means `<C-y>` on the glyph and `:Emojis toggle` anywhere on the
---line advance identically:
--->lua
---  require("cascade").setup({
---    cycle = { groups = require("emojis").cascade_groups() },
---  })
---<
---Pure data — cascade is never required here, so this is safe to call whether
---or not cascade is installed.
---@param set? string  Only this set; defaults to every configured set
---@return string[][]
function M.cascade_groups(set)
  local sets = require("emojis.config").checkbox_sets(set)
  return vim.deepcopy(sets)
end

---Count emojis in the whole current buffer.
---@return nil
function M.count()
  local scope_m = require("emojis.core.scope")
  local target = scope_m.resolve("%", 0, 0, 0)
  if target then
    require("emojis.actions").count(target)
  end
end

---Access the pure operations (clear/count/list/replace) for scripting/tests.
---@return table
function M.ops()
  return require("emojis.core.ops")
end

return M
