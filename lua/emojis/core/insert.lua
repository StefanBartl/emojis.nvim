---@module 'emojis.core.insert'
---@brief Insert a glyph at the cursor and record the use for frecency.
---@description
--- Extracted from `emojis.picker` so the insert picker and the overlay share one
--- implementation. That sharing is the point: both entry points must feed the
--- same usage histogram, otherwise the overlay's frecency ordering would only
--- reflect overlay picks and would rank a glyph the user inserts constantly via
--- telescope as "never used".
---
--- Recording is deliberately tied to insertion rather than to the UI layer, so
--- any future entry point gets it for free.

local api = vim.api

local M = {}

---Insert `glyph` at the cursor position in the current buffer/window and count
---the use. No-op when the window or buffer went invalid (the overlay closes
---before inserting, so the target window is re-resolved at call time).
---@param glyph string
---@return boolean inserted
function M.at_cursor(glyph)
  if type(glyph) ~= "string" or glyph == "" then
    return false
  end

  local win = api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then
    return false
  end
  local pos = api.nvim_win_get_cursor(win)
  local row, col = pos[1], pos[2]

  local buf = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  col = math.min(col, #line)

  api.nvim_buf_set_lines(buf, row - 1, row, false, { line:sub(1, col) .. glyph .. line:sub(col + 1) })
  pcall(api.nvim_win_set_cursor, win, { row, col + #glyph })

  require("emojis.overlay.frecency").record(glyph)

  return true
end

return M
