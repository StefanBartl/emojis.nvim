---@module 'emojis.core.checkbox'
---@brief Pure line-scoped emoji checkbox toggling / cycling.
---@description
--- Advances the emoji "checkbox" on a line one step through a configured cycle
--- set: `🔲 1. Hallo` -> `✅ 1. Hallo` -> back again.
---
--- The distinguishing property is that this is *line-scoped*, not
--- cursor-scoped: the glyph is found wherever it sits on the line, so the
--- cursor may be anywhere (typically at the end of the text being written).
--- That is deliberately the one thing cascade.nvim's word-cycle cannot do —
--- its `\k\+` tokenizer requires the cursor to be on the glyph itself. Cursor-
--- precise cycling is cascade's job and is not reimplemented here; see
--- `emojis.cascade_groups()` for feeding these same sets to it.
---
--- Detection reuses `core.patterns.match_at`, so a glyph is matched as a whole
--- grapheme (skin tone, VS16, ZWJ chains and flags included) rather than by
--- naive substring search. A plain `line:find(glyph)` would mis-fire on the
--- prefix of a longer sequence — `✔` is a genuine prefix of `✔️` — and would
--- rewrite half a grapheme.
---
--- Every function here is pure: strings and tables in, strings and tables out,
--- no Neovim API. Mirrors `core.ops` so the same headless tests apply.

local patterns = require("emojis.core.patterns")

local M = {}

---Position of `glyph` in `sets`, as (set index, position in that set).
---
---First match wins, in configured order — that is what makes an ambiguous glyph
---(one appearing in several sets) resolve deterministically instead of
---depending on table iteration order.
---@param sets string[][]
---@param glyph string
---@return integer|nil set_idx, integer|nil pos
local function locate(sets, glyph)
  for i = 1, #sets do
    local set = sets[i]
    for j = 1, #set do
      if set[j] == glyph then
        return i, j
      end
    end
  end
  return nil, nil
end

---Find the first emoji grapheme on `line` that belongs to one of `sets`.
---@param line string
---@param sets string[][]
---@return integer|nil s, integer|nil e, integer|nil set_idx, integer|nil pos
---  1-based inclusive byte span of the glyph, plus where it sits in `sets`.
function M.find(line, sets)
  local i, len = 1, #line
  while i <= len do
    local e = patterns.match_at(line, i)
    if e then
      local set_idx, pos = locate(sets, line:sub(i, e))
      if set_idx then
        return i, e, set_idx, pos
      end
      i = e + 1
    else
      i = i + 1
    end
  end
  return nil, nil, nil, nil
end

---Advance `line`'s checkbox glyph by `dir` steps (wrapping inside its set).
---
---Returns the line unchanged (and `false`) when no configured glyph is present,
---so callers can report "nothing to toggle" without a second scan.
---@param line string
---@param sets string[][]
---@param dir? integer  1 forward (default), -1 backward
---@return string line, boolean changed
function M.toggle_line(line, sets, dir)
  dir = dir or 1

  local s, e, set_idx, pos = M.find(line, sets)
  if not s then
    return line, false
  end
  ---@cast e integer
  ---@cast set_idx integer
  ---@cast pos integer

  local set = sets[set_idx]
  local nxt = ((pos - 1 + dir) % #set) + 1

  return line:sub(1, s - 1) .. set[nxt] .. line:sub(e + 1), true
end

---Insert `sets[1][1]` at the start of a line that has no checkbox yet,
---preserving indentation.
---@param line string
---@param sets string[][]
---@return string line, boolean changed
function M.add_line(line, sets)
  if #sets == 0 or #sets[1] == 0 then
    return line, false
  end

  local indent = line:match("^(%s*)") or ""
  local rest = line:sub(#indent + 1)
  if rest == "" then
    return line, false
  end

  return indent .. sets[1][1] .. " " .. rest, true
end

---Remove the checkbox glyph from a line, along with one following space.
---@param line string
---@param sets string[][]
---@return string line, boolean changed
function M.remove_line(line, sets)
  local s, e = M.find(line, sets)
  if not s then
    return line, false
  end
  ---@cast e integer

  local rest = line:sub(e + 1)
  -- Drop exactly one separating space, so `🔲 1. x` yields `1. x` rather than
  -- a stray leading space; further spacing is the user's own formatting.
  rest = rest:gsub("^ ", "", 1)

  return line:sub(1, s - 1) .. rest, true
end

---Toggle every line in `lines`, reporting how many actually changed.
---
---Lines without a configured glyph are passed through untouched rather than
---gaining one: a range toggle is "advance the checkboxes in this block", and
---silently checkbox-ing prose lines would be destructive. Use `add` for that.
---@param lines string[]
---@param sets string[][]
---@param dir? integer
---@return string[] lines, integer changed
function M.toggle(lines, sets, dir)
  local out, changed = {}, 0
  for i = 1, #lines do
    local line, did = M.toggle_line(lines[i], sets, dir)
    out[i] = line
    if did then
      changed = changed + 1
    end
  end
  return out, changed
end

---Add a checkbox to every line in `lines` that lacks one.
---@param lines string[]
---@param sets string[][]
---@return string[] lines, integer changed
function M.add(lines, sets)
  local out, changed = {}, 0
  for i = 1, #lines do
    local line = lines[i]
    if M.find(line, sets) then
      out[i] = line
    else
      local added, did = M.add_line(line, sets)
      out[i] = added
      if did then
        changed = changed + 1
      end
    end
  end
  return out, changed
end

---Remove the checkbox from every line in `lines` that has one.
---@param lines string[]
---@param sets string[][]
---@return string[] lines, integer changed
function M.remove(lines, sets)
  local out, changed = {}, 0
  for i = 1, #lines do
    local line, did = M.remove_line(lines[i], sets)
    out[i] = line
    if did then
      changed = changed + 1
    end
  end
  return out, changed
end

return M
