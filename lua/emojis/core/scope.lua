---@module 'emojis.core.scope'
---@brief Resolve a scope (+ optional Vim range) to a buffer line range.
---@description
--- Returns a `(target, err)` pair instead of raising, so callers stay in control
--- of error reporting. Line numbers in the result are 0-based and inclusive.

local api = vim.api
local fn = vim.fn

local M = {}

---@param scope Emojis.Scope
---@param range integer   0 = none, 1 = single line, 2 = line range
---@param line1 integer   1-based first range line
---@param line2 integer   1-based last range line
---@return Emojis.Target|nil target, string|nil err
function M.resolve(scope, range, line1, line2)
  local buf = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return nil, "current buffer is not valid"
  end
  local last = api.nvim_buf_line_count(buf) -- 1-based count

  -- An explicit Vim range (:'<,'>Emojis, :10,20Emojis) always wins.
  if range > 0 then
    local l1 = math.max(0, line1 - 1)
    local l2 = math.min(last - 1, line2 - 1)
    return { buf = buf, l1 = l1, l2 = l2 }, nil
  end

  if scope == "%" then
    return { buf = buf, l1 = 0, l2 = last - 1 }, nil
  elseif scope == "line" then
    local win = api.nvim_get_current_win()
    if not api.nvim_win_is_valid(win) then
      return nil, "current window is not valid"
    end
    local cur = api.nvim_win_get_cursor(win)[1] -- 1-based
    local l = math.min(math.max(1, cur), last) - 1
    return { buf = buf, l1 = l, l2 = l }, nil
  elseif scope == "word" then
    local win = api.nvim_get_current_win()
    if not api.nvim_win_is_valid(win) then
      return nil, "current window is not valid"
    end
    local cur = api.nvim_win_get_cursor(win) -- { 1-based row, 0-based byte col }
    local l = math.min(math.max(1, cur[1]), last) - 1
    local line = api.nvim_buf_get_lines(buf, l, l + 1, false)[1] or ""
    if #line == 0 then
      return nil, "cursor line is empty"
    end

    local col = math.min(math.max(1, cur[2] + 1), #line) -- 1-based byte col
    local ch = line:sub(col, col)
    if ch == " " or ch == "\t" then
      return nil, "cursor is not on a word"
    end

    local c1 = col
    while c1 > 1 do
      local prev = line:sub(c1 - 1, c1 - 1)
      if prev == " " or prev == "\t" then
        break
      end
      c1 = c1 - 1
    end

    local c2 = col
    while c2 < #line do
      local nxt = line:sub(c2 + 1, c2 + 1)
      if nxt == " " or nxt == "\t" then
        break
      end
      c2 = c2 + 1
    end

    return { buf = buf, l1 = l, l2 = l, c1 = c1, c2 = c2 }, nil
  elseif scope == "visual" then
    local vs = fn.getpos("'<")
    local ve = fn.getpos("'>")
    local a, b = vs[2], ve[2]
    if a == 0 then
      return nil, "no previous visual selection"
    end
    local l1 = math.max(0, math.min(a, b) - 1)
    local l2 = math.min(last - 1, math.max(a, b) - 1)
    return { buf = buf, l1 = l1, l2 = l2 }, nil
  elseif scope == "cwd" then
    return { buf = -1, l1 = 0, l2 = 0 }, nil -- sentinel for project scope
  else
    return nil, "unknown scope: " .. tostring(scope)
  end
end

return M
