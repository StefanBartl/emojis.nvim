---@module 'emojis.commands'
---@brief :Emojis user command — dispatch + tab completion.
---@description
--- Parses `[action] [scope]`, validates them, and routes to the action handlers,
--- the picker, or the async cwd search. A Vim range overrides the scope keyword.

local api = vim.api

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

---Context-aware tab completion: first arg = action, second arg = scope.
---@param _ string
---@param cmd_line string
---@return string[]
local function complete(_, cmd_line, _)
  local tokens = vim.split(vim.trim(cmd_line), "%s+", { trimempty = true })
  local trailing = cmd_line:sub(-1) == " "
  local n = #tokens - 1 -- args after the command name
  local arg = trailing and (n + 1) or n -- which arg is being completed

  local cands = (arg <= 1) and ACTIONS or (arg == 2 and SCOPES or {})
  local partial = (not trailing and tokens[#tokens]) or ""
  if partial == "" then
    return cands
  end

  local out = {}
  for i = 1, #cands do
    if vim.startswith(cands[i], partial) then
      out[#out + 1] = cands[i]
    end
  end
  return out
end

---Register the :Emojis command using the configured name.
---@param cfg Emojis.Config
---@return nil
function M.register(cfg)
  api.nvim_create_user_command(cfg.command, execute, {
    desc = "[emojis] :" .. cfg.command .. " [clear|insert|list|count|replace|unreplace|first|next|wrap] [word|line|visual|%|cwd]",
    nargs = "*",
    range = true,
    complete = complete,
  })
end

return M
