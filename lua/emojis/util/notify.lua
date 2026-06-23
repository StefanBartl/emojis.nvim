---@module 'emojis.util.notify'
---@brief Prefixed wrapper around vim.notify.
---@description
--- Only the UI/action layer calls this — the pure core (patterns, ops) stays
--- silent and returns values instead.

local PREFIX = "[emojis] "

local M = {}

---@param msg string
---@return nil
function M.info(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.INFO)
end

---@param msg string
---@return nil
function M.warn(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.WARN)
end

---@param msg string
---@return nil
function M.error(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.ERROR)
end

return M
