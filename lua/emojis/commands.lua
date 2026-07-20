---@module 'emojis.commands'
---@brief :Emojis user command — dispatch + tab completion, built on
---lib.nvim.usercmd.composer.
---@description
--- Parses `[action] [scope]`, validates them, and routes to the action handlers,
--- the picker, or the async cwd search. A Vim range overrides the scope keyword.
---
--- execute() is the unchanged dispatch engine: one composer route per literal
--- action reconstructs the `{fargs, range, line1, line2}` shape
--- nvim_create_user_command's callback always passed and forwards it here —
--- so validation (has(ACTIONS,...)/has(SCOPES,...), the NO_SCOPE bypass, cwd's
--- extra_globs tail) never had to be re-expressed in the route declarations.
--- This is why the scope arg stays a soft `STRING` (completion hint only, via
--- `values`), not a hard composer `enum`: NO_SCOPE actions (insert/first/next)
--- silently ignore a garbage second token today, and a hard enum would reject
--- it before execute() ever got a chance to apply that bypass.

local composer = require("lib.nvim.usercmd.composer")

local notify = require("emojis.util.notify")
local config = require("emojis.config")
local scope_m = require("emojis.core.scope")
local actions = require("emojis.actions")

local M = {}

---@type string[]
local ACTIONS = { "clear", "insert", "list", "count", "replace", "unreplace", "first", "next", "wrap" }

---@type string[]
local SCOPES = { "word", "line", "visual", "%", "cwd" }

---@type table<string, boolean>  Actions that ignore the scope argument entirely.
local NO_SCOPE = { insert = true, first = true, next = true }

---@param list string[]
---@param v string
---@return boolean
local function has(list, v)
  for i = 1, #list do
    if list[i] == v then
      return true
    end
  end
  return false
end

---Dispatch a parsed command invocation.
---@param cmd_args table  nvim_create_user_command argument table
---@return nil
local function execute(cmd_args)
  local default_scope = config.get().default_scope
  local action = (cmd_args.fargs[1] or "clear"):lower()
  local scope = (cmd_args.fargs[2] or default_scope):lower()

  if not has(ACTIONS, action) then
    notify.error(("unknown action %q. Valid: %s"):format(action, table.concat(ACTIONS, ", ")))
    return
  end
  if not NO_SCOPE[action] and not has(SCOPES, scope) then
    notify.error(("unknown scope %q. Valid: %s"):format(scope, table.concat(SCOPES, ", ")))
    return
  end

  if action == "insert" then
    require("emojis.picker").insert()
    return
  end
  if action == "first" then
    require("emojis.nav").first()
    return
  end
  if action == "next" then
    require("emojis.nav").next()
    return
  end
  if scope == "cwd" then
    local extra_globs = {}
    for i = 3, #cmd_args.fargs do
      extra_globs[#extra_globs + 1] = cmd_args.fargs[i]
    end
    require("emojis.search").run(action, extra_globs)
    return
  end

  local target, err = scope_m.resolve(scope, cmd_args.range, cmd_args.line1, cmd_args.line2)
  if not target then
    notify.error("scope error: " .. tostring(err))
    return
  end

  if action == "clear" then
    actions.edit("clear", target)
  elseif action == "replace" then
    actions.edit("replace", target)
  elseif action == "unreplace" then
    actions.edit("unreplace", target)
  elseif action == "wrap" then
    actions.edit("wrap", target)
  elseif action == "list" then
    actions.list(target)
  elseif action == "count" then
    actions.count(target)
  end
end

---@type table<string, string>
local ACTION_DESC = {
  clear = "Remove emojis from the given scope",
  insert = "Open the insert picker",
  list = "List emojis found in the given scope",
  count = "Count emojis in the given scope",
  replace = "Replace emojis with :shortcode: placeholders in the given scope",
  unreplace = "Restore :shortcode: placeholders back to emojis in the given scope",
  first = "Jump to the first emoji in the buffer",
  next = "Jump to the next emoji in the buffer (wraps)",
  wrap = "Surround emojis with the configured marker in the given scope",
}

---Reconstruct the {fargs, range, line1, line2} shape execute() expects from a
---composer ctx and dispatch — see the module doc for why forwarding to the
---unchanged execute() (rather than re-deriving its validation here) matters.
---@param action string
---@param ctx table
---@return nil
local function forward(action, ctx)
  local fargs = { action }
  if ctx.pos[1] then
    fargs[#fargs + 1] = ctx.pos[1]
  end
  for _, v in ipairs(ctx.rest) do
    fargs[#fargs + 1] = v
  end
  execute({ fargs = fargs, range = ctx.range.range, line1 = ctx.range.line1, line2 = ctx.range.line2 })
end

---@param action string
---@return table
local function action_route(action)
  return {
    path = { action },
    args = { { name = "scope", type = "STRING", values = SCOPES, optional = true } },
    desc = ACTION_DESC[action],
    run = function(ctx) forward(action, ctx) end,
  }
end

---Register the :Emojis command (name from cfg.command) via
---lib.nvim.usercmd.composer.
---@param cfg Emojis.Config
---@return nil
function M.register(cfg)
  local routes = {}
  for i = 1, #ACTIONS do
    routes[i] = action_route(ACTIONS[i])
  end

  composer.verb(cfg.command, {
    desc = "[emojis] :" .. cfg.command
      .. " [clear|insert|list|count|replace|unreplace|first|next|wrap] [word|line|visual|%|cwd]",
    range = true,
    default = function(ctx) forward("clear", ctx) end,
    routes = routes,
  })
end

return M
