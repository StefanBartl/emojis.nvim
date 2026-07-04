---@module 'emojis.core.patterns'
---@brief Pure UTF-8 byte-pattern emoji tokenizer. No Neovim API calls.
---@description
--- Lua has no `|` alternation in patterns, so emoji bytes are matched with three
--- separate byte-class patterns. A trailing Variation-Selector-16 (U+FE0F) is
--- treated as part of the preceding emoji grapheme — never as a separate token —
--- which fixes both double-counting (⚠️ == 1 emoji) and stray `:U+FE0F:` output.
---
---   P_4BYTE   F0 9F [80-BF] [80-BF]   U+1F000–U+1FFFF  main emoji block
---   P_3A      E2 [98-9F] [80-BF]      U+2600–U+27FF    Misc Symbols, Dingbats
---   P_3B      E2 [AC-AF] [80-BF]      U+2B00–U+2BFF    Misc Symbols + Arrows
---   VS16      EF B8 8F                 U+FE0F           Variation Selector-16
---
--- string.char() is used for every byte value to avoid escape-syntax ambiguity
--- across Lua 5.1 / LuaJIT.

local sc = string.char

-- 4-byte: main emoji block  U+1F000 – U+1FFFF
local P_4BYTE = sc(240, 159) .. "[" .. sc(128) .. "-" .. sc(191) .. "]" .. "[" .. sc(128) .. "-" .. sc(191) .. "]"

-- 3-byte: Misc Symbols (☀★♥⚠✅❌…)  U+2600 – U+27FF
local P_3A = sc(226) .. "[" .. sc(152) .. "-" .. sc(159) .. "]" .. "[" .. sc(128) .. "-" .. sc(191) .. "]"

-- 3-byte: Misc Symbols + Arrows (⭐…)  U+2B00 – U+2BFF
local P_3B = sc(226) .. "[" .. sc(172) .. "-" .. sc(175) .. "]" .. "[" .. sc(128) .. "-" .. sc(191) .. "]"

-- Variation Selector-16  U+FE0F  (3 bytes: EF B8 8F)
local VS16 = sc(239, 184, 143)

---@type string[]  Base patterns (without VS16), tried in order
local BASE = { P_4BYTE, P_3A, P_3B }

---@type string[]  Same patterns pre-anchored with "^" so we can match at a byte
local BASE_ANCHORED = {}
for i = 1, #BASE do
  BASE_ANCHORED[i] = "^" .. BASE[i]
end

local M = {}

M.VS16 = VS16
M.BASE = BASE

---End-byte of an emoji grapheme starting exactly at `i` (a base emoji plus an
---optional trailing VS16), or nil when no emoji starts at `i`.
---@param s string
---@param i integer  1-based start byte
---@return integer|nil end_byte
function M.match_at(s, i)
  for k = 1, #BASE_ANCHORED do
    local a, b = s:find(BASE_ANCHORED[k], i)
    if a then
      if s:sub(b + 1, b + 3) == VS16 then
        b = b + 3
      end
      return b
    end
  end
  return nil
end

---Count emoji graphemes in a string.
---@param s string
---@return integer
function M.count(s)
  local i, len, n = 1, #s, 0
  while i <= len do
    local me = M.match_at(s, i)
    if me then
      n = n + 1
      i = me + 1
    else
      i = i + 1
    end
  end
  return n
end

---Collect emoji-grapheme spans (1-based inclusive byte ranges), left to right.
---@param s string
---@return Emojis.Span[]
function M.spans(s)
  local i, len = 1, #s
  local res = {}
  while i <= len do
    local me = M.match_at(s, i)
    if me then
      res[#res + 1] = { i, me }
      i = me + 1
    else
      i = i + 1
    end
  end
  return res
end

---Decode the Unicode codepoint of the base emoji at the start of `glyph`.
---A trailing VS16 (if any) is ignored.
---@param glyph string
---@return integer
function M.codepoint(glyph)
  local b1 = glyph:byte(1) or 0
  if b1 >= 0xF0 and #glyph >= 4 then
    local b2, b3, b4 = glyph:byte(2), glyph:byte(3), glyph:byte(4)
    return ((b1 - 0xF0) * 0x40000) + ((b2 - 0x80) * 0x1000) + ((b3 - 0x80) * 0x40) + (b4 - 0x80)
  elseif b1 >= 0xE0 and #glyph >= 3 then
    local b2, b3 = glyph:byte(2), glyph:byte(3)
    return ((b1 - 0xE0) * 0x1000) + ((b2 - 0x80) * 0x40) + (b3 - 0x80)
  end
  return b1
end

return M
