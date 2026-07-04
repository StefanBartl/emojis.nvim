---@module 'emojis.util.notify'
---@brief Prefixed notification wrapper.
---@description
--- Only the UI/action layer calls this — the pure core (patterns, ops) stays
--- silent and returns values instead. Delegates to `lib.nvim.notify` when
--- available (see `emojis.util.lib`), else a plain `vim.notify` wrapper.

local lib = require("emojis.util.lib")

local M = {}

---@param msg string
---@return nil
function M.info(msg)
  lib.notifier().info(msg)
end

---@param msg string
---@return nil
function M.warn(msg)
  lib.notifier().warn(msg)
end

---@param msg string
---@return nil
function M.error(msg)
  lib.notifier().error(msg)
end

return M
