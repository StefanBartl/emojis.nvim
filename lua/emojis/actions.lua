---@module 'emojis.actions'
---@brief Buffer-facing action handlers (clear / replace / list / count).
---@description
--- These bridge the pure `core.ops` results to the editor: read lines, call the
--- pure op, write back, and notify. Buffer validity is re-checked here because
--- the target was resolved earlier and handles can go stale.

local api = vim.api
local fn = vim.fn

local notify = require("emojis.util.notify")
local ops = require("emojis.core.ops")
local config = require("emojis.config")

local M = {}

---@param buf integer
---@return boolean
local function buf_ok(buf)
  return type(buf) == "number" and api.nvim_buf_is_valid(buf)
end

---Apply a buffer-mutating action ("clear" or "replace").
---@param action "clear"|"replace"
---@param t Emojis.Target
---@return nil
function M.edit(action, t)
  if not buf_ok(t.buf) then
    notify.error("buffer is no longer valid")
    return
  end

  local lines = api.nvim_buf_get_lines(t.buf, t.l1, t.l2 + 1, false)
  if #lines == 0 then
    notify.info("range is empty")
    return
  end

  local new_lines, n
  if action == "clear" then
    new_lines, n = ops.clear(lines)
  else
    new_lines, n = ops.replace(lines, config.get().names)
  end

  if n == 0 then
    notify.info("no emojis found in scope")
    return
  end

  api.nvim_buf_set_lines(t.buf, t.l1, t.l2 + 1, false, new_lines)
  local verb = (action == "clear") and "Removed" or "Replaced"
  notify.info(("%s %d emoji%s"):format(verb, n, n == 1 and "" or "s"))
end

---List emojis in scope into the quickfix list.
---@param t Emojis.Target
---@return nil
function M.list(t)
  if not buf_ok(t.buf) then
    notify.error("buffer is no longer valid")
    return
  end

  local lines = api.nvim_buf_get_lines(t.buf, t.l1, t.l2 + 1, false)
  local entries = ops.list(lines, t.l1)
  if #entries == 0 then
    notify.info("no emojis found in scope")
    return
  end

  local name = fn.bufname(t.buf)
  local qf = {}
  for i = 1, #entries do
    local e = entries[i]
    qf[i] = { bufnr = t.buf, filename = name, lnum = e.lnum, col = e.col + 1, text = "emoji " .. e.text }
  end
  fn.setqflist({}, "r", { title = "Emojis", items = qf })
  vim.cmd("copen")
  notify.info(("Found %d emoji%s -> quickfix"):format(#entries, #entries == 1 and "" or "s"))
end

---Count emojis in scope and report.
---@param t Emojis.Target
---@return nil
function M.count(t)
  if not buf_ok(t.buf) then
    notify.error("buffer is no longer valid")
    return
  end

  local lines = api.nvim_buf_get_lines(t.buf, t.l1, t.l2 + 1, false)
  local n = ops.count(lines)
  local lc = t.l2 - t.l1 + 1
  if n == 0 then
    notify.info(("no emojis in %d line%s"):format(lc, lc == 1 and "" or "s"))
  else
    notify.info(("Found %d emoji%s in %d line%s"):format(n, n == 1 and "" or "s", lc, lc == 1 and "" or "s"))
  end
end

return M
