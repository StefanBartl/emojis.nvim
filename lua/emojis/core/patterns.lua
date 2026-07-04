---@module 'emojis.core.patterns'
---@brief Pure UTF-8 byte-pattern emoji tokenizer. No Neovim API calls.
---@description
--- Table-driven Unicode ranges instead of individually hand-derived byte
--- patterns: `RANGES` lists inclusive codepoints, `range_pattern` compiles
--- each into a Lua byte-class pattern at load time. Adding a range is a
--- one-line data change instead of computing UTF-8 bytes by hand.
---
--- A grapheme extends a base range match with, in order: an optional
--- Fitzpatrick skin-tone modifier (U+1F3FB-1F3FF), an optional
--- Variation-Selector-16 (U+FE0F), and then either:
---   - a second Regional Indicator Symbol (U+1F1E6-1F1FF), pairing two flag
---     letters into one flag grapheme (e.g. 🇩🇪), or
---   - a Zero-Width-Joiner (U+200D) chain: ZWJ + another full unit, repeated
---     (family/profession/rainbow-flag ZWJ sequences, e.g. 👨‍👩‍👧).
---
--- string.char() is used for every byte value to avoid escape-syntax
--- ambiguity across Lua 5.1 / LuaJIT.

local sc = string.char

---Encode a single Unicode codepoint to its UTF-8 bytes (plain arithmetic; no
---bitwise ops, for Lua 5.1 / LuaJIT compatibility).
---@param cp integer
---@return integer[] bytes
local function encode(cp)
  if cp < 0x80 then
    return { cp }
  elseif cp < 0x800 then
    return { 0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40) }
  elseif cp < 0x10000 then
    return {
      0xE0 + math.floor(cp / 0x1000),
      0x80 + (math.floor(cp / 0x40) % 0x40),
      0x80 + (cp % 0x40),
    }
  else
    return {
      0xF0 + math.floor(cp / 0x40000),
      0x80 + (math.floor(cp / 0x1000) % 0x40),
      0x80 + (math.floor(cp / 0x40) % 0x40),
      0x80 + (cp % 0x40),
    }
  end
end

---@param bytes integer[]
---@return string
local function encode_str(bytes)
  if #bytes == 1 then
    return sc(bytes[1])
  elseif #bytes == 2 then
    return sc(bytes[1], bytes[2])
  elseif #bytes == 3 then
    return sc(bytes[1], bytes[2], bytes[3])
  else
    return sc(bytes[1], bytes[2], bytes[3], bytes[4])
  end
end

---Build a Lua pattern matching every codepoint in the inclusive range
---[lo, hi]. Requires lo/hi to encode to the same UTF-8 byte length and the
---range to be aligned so a byte-class per position suffices — true for the
---block-aligned Unicode ranges used here.
---@param lo integer
---@param hi integer
---@return string pattern
local function range_pattern(lo, hi)
  local a, b = encode(lo), encode(hi)
  assert(#a == #b, "range crosses a UTF-8 length boundary")
  local parts = {}
  for i = 1, #a do
    if a[i] == b[i] then
      parts[i] = sc(a[i])
    else
      parts[i] = "[" .. sc(a[i]) .. "-" .. sc(b[i]) .. "]"
    end
  end
  return table.concat(parts)
end

---@type integer[][]  Inclusive codepoint ranges treated as "base" emoji.
local RANGES = {
  { 0x1F000, 0x1FFFF }, -- main emoji plane: pictographs, emoticons, transport,
  -- supplemental symbols, Enclosed Alphanumeric Supplement
  -- (incl. Regional Indicator flag letters)
  { 0x2600, 0x27FF }, -- Misc Symbols + Dingbats
  { 0x2B00, 0x2BFF }, -- Misc Symbols and Arrows
  { 0x2300, 0x23FF }, -- Misc Technical (watch/hourglass/media symbols)
}

---@type string[]  Base patterns, tried in order
local BASE = {}
for i = 1, #RANGES do
  BASE[i] = range_pattern(RANGES[i][1], RANGES[i][2])
end

---@type string[]  Same patterns pre-anchored with "^" so we can match at a byte
local BASE_ANCHORED = {}
for i = 1, #BASE do
  BASE_ANCHORED[i] = "^" .. BASE[i]
end

-- Variation Selector-16  U+FE0F
local VS16 = encode_str(encode(0xFE0F))

-- Zero-Width Joiner  U+200D
local ZWJ = encode_str(encode(0x200D))

-- Fitzpatrick skin-tone modifiers  U+1F3FB-1F3FF
local SKIN_TONE_ANCHORED = "^" .. range_pattern(0x1F3FB, 0x1F3FF)

-- Regional Indicator Symbols  U+1F1E6-1F1FF (paired into flag emoji)
local REGIONAL_ANCHORED = "^" .. range_pattern(0x1F1E6, 0x1F1FF)

local M = {}

M.VS16 = VS16
M.BASE = BASE

---Encode a single Unicode codepoint back to its UTF-8 string (inverse of
---`codepoint()`). Used by `core.ops.unreplace` to rebuild a glyph.
---@param cp integer
---@return string
function M.encode(cp)
  return encode_str(encode(cp))
end

---Match one of the base ranges at exactly `i`.
---@param s string
---@param i integer
---@return integer|nil end_byte
local function match_base(s, i)
  for k = 1, #BASE_ANCHORED do
    local a, b = s:find(BASE_ANCHORED[k], i)
    if a then
      return b
    end
  end
  return nil
end

---Match one "unit": a base emoji plus an optional trailing skin-tone
---modifier and/or VS16 (skin-tone never applies to Regional Indicators).
---@param s string
---@param i integer
---@return integer|nil end_byte, boolean is_regional
local function match_unit(s, i)
  local b = match_base(s, i)
  if not b then
    return nil, false
  end
  local is_regional = s:find(REGIONAL_ANCHORED, i) ~= nil

  if not is_regional and s:find(SKIN_TONE_ANCHORED, b + 1) then
    b = b + 4
  end
  if s:sub(b + 1, b + 3) == VS16 then
    b = b + 3
  end

  return b, is_regional
end

---End-byte of an emoji grapheme starting exactly at `i` (a base emoji plus
---optional skin-tone/VS16, a paired flag, or a ZWJ chain), or nil when no
---emoji starts at `i`.
---@param s string
---@param i integer  1-based start byte
---@return integer|nil end_byte
function M.match_at(s, i)
  local b, is_regional = match_unit(s, i)
  if not b then
    return nil
  end

  if is_regional then
    -- Pair two adjacent Regional Indicator Symbols into one flag grapheme.
    local b2, is_regional2 = match_unit(s, b + 1)
    if b2 and is_regional2 then
      return b2
    end
    return b
  end

  -- ZWJ chain: ZWJ + another unit, repeated.
  while s:sub(b + 1, b + 3) == ZWJ do
    local b2 = match_unit(s, b + 4)
    if not b2 then
      break
    end
    b = b2
  end

  return b
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
---A trailing VS16, skin-tone modifier, ZWJ chain, or flag pair (if any) is
---ignored — only the first component is decoded.
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
