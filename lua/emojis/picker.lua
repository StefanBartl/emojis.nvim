---@module 'emojis.picker'
---@brief Insert an emoji at the cursor via vim.ui.select.
---@description
--- Selection is mapped back to the configured picks by index (not by parsing the
--- display string), which is robust against labels that contain spaces.

local api = vim.api

local notify = require("emojis.util.notify")
local config = require("emojis.config")

local M = {}

---Open the picker and insert the chosen emoji at the cursor position.
---@return nil
function M.insert()
  local picks = config.get().picks
  if type(picks) ~= "table" or #picks == 0 then
    notify.warn("no emojis configured for the picker")
    return
  end

  local items = {}
  for i = 1, #picks do
    items[i] = picks[i][1] .. "  " .. picks[i][2]
  end

  vim.ui.select(items, { prompt = "Insert emoji:" }, function(_, idx)
    if not idx then
      return
    end
    local entry = picks[idx]
    if not entry then
      return
    end
    local icon = entry[1]

    local win = api.nvim_get_current_win()
    if not api.nvim_win_is_valid(win) then
      return
    end
    local pos = api.nvim_win_get_cursor(win)
    local row, col = pos[1], pos[2]

    local buf = api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
      return
    end
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    col = math.min(col, #line)

    api.nvim_buf_set_lines(buf, row - 1, row, false,
      { line:sub(1, col) .. icon .. line:sub(col + 1) })
    pcall(api.nvim_win_set_cursor, win, { row, col + #icon })
  end)
end

return M
