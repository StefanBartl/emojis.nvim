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

---When `t` carries a byte sub-range (the `word` scope), narrow `lines` (a
---single-line array) to that substring. Returns the column offset to add
---back onto any reported byte columns; 0 when no sub-range applies.
---@param t Emojis.Target
---@param lines string[]
---@return string[] work, integer col_offset
local function scoped(t, lines)
  if t.c1 and t.c2 and #lines == 1 then
    return { lines[1]:sub(t.c1, t.c2) }, t.c1 - 1
  end
  return lines, 0
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

  local work = scoped(t, lines)

  local new_lines, n
  if action == "clear" then
    new_lines, n = ops.clear(work)
  else
    new_lines, n = ops.replace(work, config.get().names)
  end

  if n == 0 then
    notify.info("no emojis found in scope")
    return
  end

  if t.c1 and t.c2 and #lines == 1 then
    local full = lines[1]
    local rebuilt = full:sub(1, t.c1 - 1) .. new_lines[1] .. full:sub(t.c2 + 1)
    api.nvim_buf_set_lines(t.buf, t.l1, t.l2 + 1, false, { rebuilt })
  else
    api.nvim_buf_set_lines(t.buf, t.l1, t.l2 + 1, false, new_lines)
  end
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
  local work, col_offset = scoped(t, lines)
  local entries = ops.list(work, t.l1)
  if #entries == 0 then
    notify.info("no emojis found in scope")
    return
  end
  if col_offset > 0 then
    for i = 1, #entries do
      entries[i].col = entries[i].col + col_offset
    end
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
  local work = scoped(t, lines)
  local n = ops.count(work)
  local lc = t.l2 - t.l1 + 1
  if n == 0 then
    notify.info(("no emojis in %d line%s"):format(lc, lc == 1 and "" or "s"))
  else
    notify.info(("Found %d emoji%s in %d line%s"):format(n, n == 1 and "" or "s", lc, lc == 1 and "" or "s"))
  end
end

return M
