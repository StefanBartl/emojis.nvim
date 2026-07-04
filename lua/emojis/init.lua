---@module 'emojis'
---@brief Public entry point for emojis.nvim.
---@description
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
---@param opts? Emojis.Config|table
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
