---@module 'emojis.unicode.data'
--- Lazy, cached Unicode name lookup, sourced from the UCD's own
--- `UnicodeData.txt` -- the same authoritative source and `;`-delimited
--- format `chrisbra/unicode.vim`'s own `:UnicodeName`/`:UnicodeSearch`/
--- `:UnicodeTable` read, parsed here instead of shipped as a bundled table:
--- the UCD is ~1.9MB and revises with every Unicode release, so a baked-in
--- copy would go stale the moment it landed in this repo.
---
--- Downloaded once per machine (via `curl`, on `$PATH`) into
--- `stdpath("cache")/emojis/UnicodeData.txt`, then parsed into an in-memory
--- table the first time any `:Emojis unicode` command needs it -- ~34,000
--- lines, comfortably under 100ms to parse. No bundled fallback: without
--- `curl` or an already-cached copy, every `unicode.*` command reports why
--- and does nothing else, same as `M.ensure()`'s second return value says.
---
--- Large contiguous blocks (CJK Unified Ideographs, Tangut, ...) are not
--- stored one row per codepoint -- the UCD itself represents them as a
--- `<Label, First>`/`<Label, Last>` pair rather than one row per character,
--- which is also why unicode.vim's own dict returns the *bracketed marker*
--- verbatim ("<CJK Ideograph, First>") for a character in one of these
--- blocks rather than a real name. `M.ranges` keeps the (few dozen) pairs
--- instead, and `M.name_for` synthesizes the Unicode-standard "PREFIX-HEX"
--- name (e.g. "CJK UNIFIED IDEOGRAPH-4E2D") for a codepoint that falls in
--- one, the same convention `unicodedata.name()` uses for these blocks.

local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/emojis"
local CACHE_FILE = CACHE_DIR .. "/UnicodeData.txt"
local URL = "https://www.unicode.org/Public/UNIDATA/UnicodeData.txt"

---@class Emojis.Unicode.Data
---@field by_cp table<integer, string>
---@field list {cp: integer, name: string}[]
---@field ranges {lo: integer, hi: integer, label: string}[]

---@type Emojis.Unicode.Data|nil
local loaded

---@type table<string, string>  UCD range label -> synthesized-name prefix.
--- Not exhaustive -- covers the blocks large enough that the UCD represents
--- them as a First/Last pair at all. A label missing here falls back to its
--- own uppercased text, still a usable (if less standard) name.
local SYNTH_PREFIX = {
  ["CJK Ideograph"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension A"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension B"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension C"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension D"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension E"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension F"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension G"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension H"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Compatibility Ideograph"] = "CJK COMPATIBILITY IDEOGRAPH",
  ["Tangut Ideograph"] = "TANGUT IDEOGRAPH",
  ["Tangut Ideograph Supplement"] = "TANGUT IDEOGRAPH",
  ["Nushu Character"] = "NUSHU CHARACTER",
  ["Hangul Syllable"] = "HANGUL SYLLABLE",
  ["Non Private Use High Surrogate"] = "SURROGATE",
  ["Private Use High Surrogate"] = "SURROGATE",
  ["Low Surrogate"] = "SURROGATE",
  ["Private Use"] = "PRIVATE USE",
  ["Plane 15 Private Use"] = "PRIVATE USE",
  ["Plane 16 Private Use"] = "PRIVATE USE",
}

---Synthesize the standard "PREFIX-HEX" name for a codepoint inside a
---First/Last range, e.g. ("CJK Ideograph", 0x4E2D) -> "CJK UNIFIED
---IDEOGRAPH-4E2D".
---@param label string
---@param cp integer
---@return string
---@internal
local function synth_name(label, cp)
  local prefix = SYNTH_PREFIX[label] or label:upper()
  return ("%s-%04X"):format(prefix, cp)
end

---Parse `UnicodeData.txt`'s own `;`-delimited format. Field indices (1-based,
---from a `;`-split line) match the UCD's documented layout: 1 = codepoint
---(hex), 2 = Name, 11 = Unicode_1_Name (the pre-2.0 alias, still the only
---name some control codes have).
---@param raw string  file contents
---@return Emojis.Unicode.Data
function M.parse(raw)
  local by_cp, list, ranges = {}, {}, {}
  ---@type {cp: integer, label: string}|nil
  local pending
  for line in raw:gmatch("[^\r\n]+") do
    local fields = {}
    for field in (line .. ";"):gmatch("(.-);") do
      fields[#fields + 1] = field
    end
    local hex, name, old_name = fields[1], fields[2], fields[11]
    local cp = hex and tonumber(hex, 16)
    if cp and name and name ~= "" then
      local first_label = name:match("^<(.+), First>$")
      local last_label = name:match("^<(.+), Last>$")
      if first_label then
        pending = { cp = cp, label = first_label }
      elseif last_label and pending and pending.label == last_label then
        ranges[#ranges + 1] = { lo = pending.cp, hi = cp, label = last_label }
        pending = nil
      else
        local resolved = name
        if resolved:sub(1, 1) == "<" and old_name and old_name ~= "" then
          resolved = old_name
        end
        if resolved ~= "" and resolved:sub(1, 1) ~= "<" then
          by_cp[cp] = resolved
          list[#list + 1] = { cp = cp, name = resolved }
        end
      end
    end
  end
  return { by_cp = by_cp, list = list, ranges = ranges }
end

---The name for a codepoint: an exact UCD row, else a synthesized
---range-block name, else nil (genuinely unnamed / unassigned).
---@param data Emojis.Unicode.Data
---@param cp integer
---@return string|nil
function M.name_for(data, cp)
  local exact = data.by_cp[cp]
  if exact then
    return exact
  end
  for i = 1, #data.ranges do
    local r = data.ranges[i]
    if cp >= r.lo and cp <= r.hi then
      return synth_name(r.label, cp)
    end
  end
  return nil
end

---@return boolean
function M.cached()
  return vim.fn.filereadable(CACHE_FILE) == 1
end

---Download `UnicodeData.txt` via `curl` into the cache file. Blocking (the
---same synchronous download unicode.vim's own `s:CheckDir` does) -- notifies
---first so a multi-second stall on first use is not mistaken for a hang.
---@return boolean ok, string|nil err
function M.download()
  if vim.fn.executable("curl") ~= 1 then
    return false, "curl not found on $PATH"
  end
  vim.fn.mkdir(CACHE_DIR, "p")
  require("emojis.util.lib").notifier().info("downloading Unicode name data (once, cached)...")
  local result = vim.system({ "curl", "-sSL", "--max-time", "20", "-o", CACHE_FILE, URL }):wait()
  if result.code ~= 0 or vim.fn.filereadable(CACHE_FILE) ~= 1 then
    pcall(vim.fn.delete, CACHE_FILE)
    return false, ("download failed (curl exit %s)"):format(tostring(result.code))
  end
  return true
end

---Ensure the parsed table is loaded, downloading first if there is no cache
---yet. Memoized -- later calls in the same session are free.
---@return Emojis.Unicode.Data|nil data, string|nil err
function M.ensure()
  if loaded then
    return loaded
  end
  if not M.cached() then
    local ok, err = M.download()
    if not ok then
      return nil, err
    end
  end
  local ok, raw = pcall(function()
    return table.concat(vim.fn.readfile(CACHE_FILE), "\n")
  end)
  if not ok then
    return nil, "cache file unreadable: " .. tostring(raw)
  end
  loaded = M.parse(raw)
  return loaded
end

---For tests: drop the in-memory table without touching the cache file.
---@return nil
function M.reset()
  loaded = nil
end

return M
