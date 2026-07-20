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
local patterns = require("emojis.core.patterns")

local M = {}

local PREVIEW_NS = api.nvim_create_namespace("emojis_preview")

---Briefly highlight the emoji spans about to be mutated. No-op unless
---`cfg.enable` is true. Blocks for `cfg.duration_ms` (redrawing first) so the
---highlight is actually visible before the caller mutates the buffer.
---@param buf integer
---@param base_line integer  0-based first line of `work`
---@param work string[]
---@param col_offset integer  byte offset added to span columns (word scope)
---@param cfg Emojis.Config.Preview
---@return nil
local function preview_spans(buf, base_line, work, col_offset, cfg)
  if not cfg.enable then
    return
  end
  for li = 1, #work do
    local spans = patterns.spans(work[li])
    for i = 1, #spans do
      local sp = spans[i]
      pcall(api.nvim_buf_set_extmark, buf, PREVIEW_NS, base_line + li - 1, col_offset + sp[1] - 1, {
        end_col = col_offset + sp[2],
        hl_group = cfg.hl_group,
      })
    end
  end
  vim.cmd("redraw")
  vim.wait(cfg.duration_ms)
  api.nvim_buf_clear_namespace(buf, PREVIEW_NS, 0, -1)
end

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

---@type table<string, string>  action -> past-tense verb for the notify message
local VERB = { clear = "Removed", replace = "Replaced", unreplace = "Restored", wrap = "Wrapped" }

---Apply a buffer-mutating action ("clear", "replace", "unreplace", or "wrap").
---@param action "clear"|"replace"|"unreplace"|"wrap"
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

  local work, col_offset = scoped(t, lines)

  if action == "clear" or action == "replace" then
    preview_spans(t.buf, t.l1, work, col_offset, config.get().preview)
  end

  local new_lines, n
  if action == "clear" then
    new_lines, n = ops.clear(work)
  elseif action == "replace" then
    new_lines, n = ops.replace(work, config.get().names)
  elseif action == "unreplace" then
    new_lines, n = ops.unreplace(work, config.get().names)
  else
    local wrap_cfg = config.get().wrap
    new_lines, n = ops.wrap(work, wrap_cfg.prefix, wrap_cfg.suffix)
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
  notify.info(("%s %d emoji%s"):format(VERB[action], n, n == 1 and "" or "s"))
end

---@type table<string, {fn: string, verb: string}>  checkbox op -> pure fn + message verb
local CHECKBOX_OPS = {
  toggle = { fn = "toggle", verb = "Toggled" },
  add = { fn = "add", verb = "Added" },
  remove = { fn = "remove", verb = "Removed" },
}

---Cycle / add / remove emoji checkboxes across a target's lines.
---
---Unlike `M.edit`, this ignores a `word` sub-range: a checkbox belongs to its
---whole line, and cycling it based on which word the cursor happens to sit in
---would be surprising. The scope only ever selects *which lines* are affected.
---@param op "toggle"|"add"|"remove"
---@param t Emojis.Target
---@param set_name? string  nil/"" searches every configured set
---@param dir? integer      1 forward (default), -1 backward; `toggle` only
---@return nil
function M.checkbox(op, t, set_name, dir)
  if not buf_ok(t.buf) then
    notify.error("buffer is no longer valid")
    return
  end

  local spec = CHECKBOX_OPS[op]
  if not spec then
    notify.error(("unknown checkbox op %q"):format(tostring(op)))
    return
  end

  local sets, err = config.checkbox_sets(set_name)
  if err then
    notify.error(err .. ". Valid: " .. table.concat(config.checkbox_set_names(), ", "))
    return
  end
  if #sets == 0 then
    notify.warn("no checkbox sets configured")
    return
  end

  local lines = api.nvim_buf_get_lines(t.buf, t.l1, t.l2 + 1, false)
  if #lines == 0 then
    notify.info("range is empty")
    return
  end

  local checkbox = require("emojis.core.checkbox")
  local new_lines, n = checkbox[spec.fn](lines, sets, dir)

  if n == 0 then
    notify.info(op == "add" and "every line already has a checkbox" or "no checkbox found in scope")
    return
  end

  api.nvim_buf_set_lines(t.buf, t.l1, t.l2 + 1, false, new_lines)
  notify.info(("%s %d checkbox%s"):format(spec.verb, n, n == 1 and "" or "es"))
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
