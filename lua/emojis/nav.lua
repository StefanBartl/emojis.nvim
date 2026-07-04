---@module 'emojis.nav'
---@brief Cursor navigation to the first / next emoji in the buffer.
---@description
--- Moves the cursor instead of populating the quickfix list (see
--- `actions.list` for that). `next()` wraps around to the top of the buffer
--- if nothing is found below the cursor.

local api = vim.api

local notify = require("emojis.util.notify")
local patterns = require("emojis.core.patterns")

local M = {}

---Scan lines `[from_line, to_line]` (0-based, inclusive) for the first emoji
---at/after `from_col` (1-based byte column) on `from_line`.
---@param buf integer
---@param from_line integer
---@param from_col integer  1-based byte column on from_line
---@param to_line integer
---@return integer|nil line, integer|nil col  0-based line, 0-based byte col
local function scan(buf, from_line, from_col, to_line)
  for l = from_line, to_line do
    local line = api.nvim_buf_get_lines(buf, l, l + 1, false)[1] or ""
    local from = (l == from_line) and from_col or 1
    local spans = patterns.spans(line)
    for i = 1, #spans do
      if spans[i][1] >= from then
        return l, spans[i][1] - 1
      end
    end
  end
  return nil
end

---Move the cursor to the emoji at/after `(start_line, start_col)`, optionally
---wrapping around to the buffer start if none is found.
---@param start_line integer  0-based
---@param start_col integer   1-based byte column
---@param wrap boolean
local function goto_emoji(start_line, start_col, wrap)
  local win = api.nvim_get_current_win()
  local buf = api.nvim_get_current_buf()
  if not (api.nvim_win_is_valid(win) and api.nvim_buf_is_valid(buf)) then
    return
  end
  local last = api.nvim_buf_line_count(buf) -- 1-based count

  local l, c = scan(buf, start_line, start_col, last - 1)
  if not l and wrap and start_line > 0 then
    l, c = scan(buf, 0, 1, start_line)
  end
  if not l then
    notify.info("no emoji found")
    return
  end
  api.nvim_win_set_cursor(win, { l + 1, c })
end

---Move the cursor to the first emoji in the buffer (top to bottom).
---@return nil
function M.first()
  goto_emoji(0, 1, false)
end

---Move the cursor to the next emoji after the cursor, wrapping to the top of
---the buffer if none is found below.
---@return nil
function M.next()
  local win = api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then
    return
  end
  local pos = api.nvim_win_get_cursor(win) -- { 1-based row, 0-based col }
  goto_emoji(pos[1] - 1, pos[2] + 2, true)
end

return M
