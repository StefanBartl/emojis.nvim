---@module 'emojis.core.ops'
---@brief Pure emoji operations on string arrays. No Neovim API calls.
---@description
--- All four operations build on the grapheme tokenizer in `core.patterns`, so a
--- VS16-decorated emoji like ⚠️ is consistently treated as a single emoji.
---
--- `clear` additionally collapses whitespace: when a removed emoji (or a run of
--- adjacent emojis) had a single space on both sides, the result keeps exactly
--- one space instead of leaving two. " 🚀 " -> " ", not "  ".

local patterns = require("emojis.core.patterns")
local VS16 = patterns.VS16

local M = {}

---Clear emojis from a single line, collapsing both-side spaces of each removed
---emoji run to one space.
---@param s string
---@return string cleaned, integer removed
function M._clear_line(s)
  local pieces, total = {}, 0
  local len = #s
  local i, run_start = 1, 1

  while i <= len do
    local me = patterns.match_at(s, i)
    if me then
      -- Flush the verbatim text accumulated before this emoji run.
      if i > run_start then
        pieces[#pieces + 1] = s:sub(run_start, i - 1)
      end
      total = total + 1

      -- Extend across directly adjacent emojis / stray VS16 so a run counts as
      -- one unit for the space-collapse decision.
      local j = me + 1
      while true do
        local me2 = patterns.match_at(s, j)
        if me2 then
          total = total + 1
          j = me2 + 1
        elseif s:sub(j, j + 2) == VS16 then
          j = j + 3
        else
          break
        end
      end

      local prev  = s:sub(i - 1, i - 1)
      local nextc = s:sub(j, j)
      if prev == " " and nextc == " " then
        run_start = j + 1  -- drop the emoji run AND one trailing space
      else
        run_start = j
      end
      i = run_start

    elseif s:sub(i, i + 2) == VS16 then
      -- Stray VS16 not attached to a base emoji: strip silently (no count).
      if i > run_start then
        pieces[#pieces + 1] = s:sub(run_start, i - 1)
      end
      run_start = i + 3
      i = run_start

    else
      i = i + 1
    end
  end

  if len >= run_start then
    pieces[#pieces + 1] = s:sub(run_start, len)
  end
  return table.concat(pieces), total
end

---@param lines string[]
---@return string[] cleaned, integer removed
function M.clear(lines)
  local out, total = {}, 0
  for li = 1, #lines do
    local cleaned, n = M._clear_line(lines[li])
    out[li] = cleaned
    total = total + n
  end
  return out, total
end

---@param lines string[]
---@return integer
function M.count(lines)
  local total = 0
  for li = 1, #lines do
    total = total + patterns.count(lines[li])
  end
  return total
end

---@param lines string[]
---@param line_offset integer  (first_1based_line - 1)
---@return Emojis.ListEntry[]
function M.list(lines, line_offset)
  line_offset = line_offset or 0
  local entries = {}
  for li = 1, #lines do
    local line = lines[li]
    local spans = patterns.spans(line)
    for k = 1, #spans do
      local sp = spans[k]
      entries[#entries + 1] = {
        lnum = li + line_offset,
        col  = sp[1] - 1,
        text = line:sub(sp[1], sp[2]),
      }
    end
  end
  -- Spans are produced left-to-right and lines iterate in order, so entries are
  -- already sorted; no extra sort needed.
  return entries
end

---Replace each emoji with its `:name:` placeholder (or `:U+XXXX:` fallback).
---@param lines string[]
---@param names table<integer, string>  codepoint -> :name:
---@return string[] replaced, integer count
function M.replace(lines, names)
  names = names or {}
  local out, total = {}, 0

  for li = 1, #lines do
    local s = lines[li]
    local spans = patterns.spans(s)
    if #spans == 0 then
      out[li] = s
    else
      local pieces, last = {}, 1
      for k = 1, #spans do
        local sp = spans[k]
        if sp[1] > last then
          pieces[#pieces + 1] = s:sub(last, sp[1] - 1)
        end
        local glyph = s:sub(sp[1], sp[2])
        local cp = patterns.codepoint(glyph)
        pieces[#pieces + 1] = names[cp] or string.format(":U+%04X:", cp)
        total = total + 1
        last = sp[2] + 1
      end
      if last <= #s then
        pieces[#pieces + 1] = s:sub(last)
      end
      out[li] = table.concat(pieces)
    end
  end

  return out, total
end

return M
