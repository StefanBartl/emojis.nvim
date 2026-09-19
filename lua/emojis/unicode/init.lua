---@module 'emojis.unicode'
--- `:Emojis unicode name|search|table|digraphs` -- the `chrisbra/unicode.vim`
--- replacement: `:UnicodeName`, `:UnicodeSearch`, `:UnicodeTable`,
--- `:Digraphs`. Dispatch target for `emojis.commands`' `unicode` action; see
--- that module for the `[unicode] [sub] [...]` argument shape.
---
--- The codepoint decode (`emojis.util.lib.utf8_decode`) and re-encode
--- (`emojis.core.patterns.encode`) this reuses were already emojis.nvim's
--- own UTF-8 machinery for the emoji tokenizer -- the "hard half" of
--- `:UnicodeName` the cross-feature report named. The name table
--- (`emojis.unicode.data`) and digraph list (`emojis.unicode.digraphs`) are
--- new: one fetched from the UCD once per machine, the other read straight
--- off Neovim's own `vim.fn.digraph_*`.

local notify = require("emojis.util.notify")
local patterns = require("emojis.core.patterns")
local data_mod = require("emojis.unicode.data")
local digraphs_mod = require("emojis.unicode.digraphs")

local M = {}

---The character at the cursor, as a single Unicode character (not byte) --
---`vim.fn.charidx`/`strcharpart` do the UTF-8-aware slicing, so this never
---needs its own byte-boundary math.
---@return string|nil
---@internal
local function char_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-based byte col
  local charidx = vim.fn.charidx(line, col)
  if charidx < 0 then
    return nil
  end
  local ch = vim.fn.strcharpart(line, charidx, 1)
  if ch == "" then
    return nil
  end
  return ch
end

---The name for `cp`, preferring emojis.nvim's own curated catalog (fast,
---needs no download) over the full UCD table (only consulted -- and only
---downloaded -- when the curated table has nothing for this codepoint).
---@param cp integer
---@return string|nil name, string|nil err  err is set only when the UCD
---        fallback was needed and failed; a curated hit never sets it
---@internal
local function resolve_name(cp)
  local curated = require("emojis.config").get().names[cp]
  if curated then
    -- ":white_check_mark:" -> "WHITE CHECK MARK", the Unicode-name shape,
    -- so a curated and a UCD-sourced result read the same way.
    return (curated:gsub("^:", ""):gsub(":$", ""):gsub("_", " "):upper())
  end
  local data, err = data_mod.ensure()
  if not data then
    return nil, err
  end
  return data_mod.name_for(data, cp), nil
end

---@class Emojis.Unicode.Info
---@field cp integer
---@field glyph string
---@field hex string    "U+00E9"
---@field dec string    "233"
---@field name string|nil
---@field name_err string|nil
---@field digraphs string[]
---@field html string    "&#xE9;"
---@field regex string   "\%u00E9" -- a Vim pattern matching this codepoint

---Gather everything `:Emojis unicode name` reports about one codepoint.
---@param cp integer
---@return Emojis.Unicode.Info
function M.info(cp)
  local glyph = patterns.encode(cp)
  local name, name_err = resolve_name(cp)
  return {
    cp = cp,
    glyph = glyph,
    hex = ("U+%04X"):format(cp),
    dec = tostring(cp),
    name = name,
    name_err = name_err,
    digraphs = digraphs_mod.for_char(glyph),
    html = ("&#x%X;"):format(cp),
    regex = ("\\%%u%04X"):format(cp),
  }
end

---@type table<string, fun(info: Emojis.Unicode.Info): string>
local REGISTER_TYPES = {
  value = function(info)
    return info.dec
  end,
  hex = function(info)
    return info.hex
  end,
  name = function(info)
    return info.name or ""
  end,
  html = function(info)
    return info.html
  end,
  regex = function(info)
    return info.regex
  end,
  digraph = function(info)
    return info.digraphs[1] or ""
  end,
}

---`:Emojis unicode name [reg [type]]` -- report the character under the
---cursor, optionally saving one representation (`type`, default "name")
---into register `reg`.
---@param reg string|nil  a register name ("a".."z", '"', etc.)
---@param reg_type string|nil  one of REGISTER_TYPES' keys
---@return nil
function M.name_at_cursor(reg, reg_type)
  local ch = char_under_cursor()
  if not ch then
    notify.info("no character under the cursor")
    return
  end

  local cp = require("emojis.util.lib").utf8_decode(ch, 1)
  if not cp then
    notify.error("could not decode the character under the cursor")
    return
  end

  local info = M.info(cp)
  local msg = ("%s  %s  %s"):format(info.hex, info.glyph, info.name or "(name unknown)")
  if info.name_err then
    msg = msg .. ("  [name lookup unavailable: %s]"):format(info.name_err)
  end
  if #info.digraphs > 0 then
    msg = msg .. ("\ndigraph: %s"):format(table.concat(info.digraphs, ", "))
  end
  notify.info(msg)

  if reg and reg ~= "" then
    local getter = REGISTER_TYPES[(reg_type or "name"):lower()]
    if not getter then
      notify.error(("unknown register type %q. Valid: %s"):format(reg_type, table.concat(vim.tbl_keys(REGISTER_TYPES), ", ")))
      return
    end
    vim.fn.setreg(reg, getter(info))
    notify.info(("saved to register %q"):format(reg))
  end
end

---Case-insensitive substring match over the UCD name table plus emojis.nvim's
---own curated catalog. A `U+xxxx` / `0xNNNN` / plain decimal query looks up
---that one codepoint instead of scanning names.
---@param query string
---@return Emojis.Unicode.Info[]
---@internal
local function find(query)
  local hex = query:match("^[uU]%+(%x+)$") or query:match("^0[xX](%x+)$")
  local cp_query = hex and tonumber(hex, 16) or (query:match("^%d+$") and tonumber(query))
  if cp_query then
    return { M.info(cp_query) }
  end

  local data, err = data_mod.ensure()
  if not data then
    notify.error("unicode search: " .. tostring(err))
    return {}
  end

  local needle = query:lower()
  local results = {}
  local cfg_names = require("emojis.config").get().names
  for cp, label in pairs(cfg_names) do
    if label:lower():find(needle, 1, true) then
      results[#results + 1] = M.info(cp)
    end
  end
  for i = 1, #data.list do
    local entry = data.list[i]
    if entry.name:lower():find(needle, 1, true) then
      results[#results + 1] = M.info(entry.cp)
      if #results >= 200 then
        break
      end
    end
  end
  table.sort(results, function(a, b)
    return a.cp < b.cp
  end)
  return results
end

---`:Emojis unicode search[!] <query>` -- `query` is either a name substring
---or a `U+xxxx`/`0xNNNN`/decimal value. Without `!`, picking a result just
---reports it (like `name_at_cursor`); with `!`, picking one inserts its
---glyph at the cursor -- the same split `chrisbra/unicode.vim`'s own bang
---makes.
---@param query string
---@param insert boolean
---@return nil
function M.search(query, insert)
  if query == "" then
    notify.error("usage: :Emojis unicode search[!] <name substring | U+xxxx | 0xNNNN | decimal>")
    return
  end

  local results = find(query)
  if #results == 0 then
    notify.info(("no match for %q"):format(query))
    return
  end

  vim.ui.select(results, {
    prompt = ("Unicode: %d match%s for %q"):format(#results, #results == 1 and "" or "es", query),
    format_item = function(info)
      return ("%s  %s  %s"):format(info.hex, info.glyph, info.name or "(name unknown)")
    end,
  }, function(choice)
    if not choice then
      return
    end
    if insert then
      vim.api.nvim_put({ choice.glyph }, "c", true, true)
    else
      notify.info(("%s  %s  %s"):format(choice.hex, choice.glyph, choice.name or "(name unknown)"))
    end
  end)
end

---Open a scratch buffer listing the full loaded name table, one line per
---character: "U+XXXX <glyph> NAME". Downloads the UCD data first if it is
---not cached yet -- see `emojis.unicode.data`.
---@return nil
function M.table_open()
  local data, err = data_mod.ensure()
  if not data then
    notify.error("unicode table: " .. tostring(err))
    return
  end

  local sorted = {}
  for i = 1, #data.list do
    sorted[i] = data.list[i]
  end
  table.sort(sorted, function(a, b)
    return a.cp < b.cp
  end)

  local lines = {}
  for i = 1, #sorted do
    local e = sorted[i]
    lines[i] = ("U+%04X  %s  %s"):format(e.cp, patterns.encode(e.cp), e.name)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, buf, "Unicode Table")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
end

---Open a scratch buffer listing every digraph Neovim knows, one line per
---code: "e' -> é". Needs no download -- see `emojis.unicode.digraphs`.
---@return nil
function M.digraphs_open()
  local entries = digraphs_mod.list()
  local sorted = {}
  for i = 1, #entries do
    sorted[i] = entries[i]
  end
  table.sort(sorted, function(a, b)
    return a.code < b.code
  end)

  local lines = {}
  for i = 1, #sorted do
    lines[i] = ("%-3s -> %s"):format(sorted[i].code, sorted[i].char)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, buf, "Digraphs")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
end

---Dispatch target for `emojis.commands`' `unicode` action.
---@param fargs string[]  `{"unicode", sub, ...}`, exactly what `:Emojis`'s
---       own `execute()` passes as `cmd_args.fargs`
---@param bang boolean
---@return nil
function M.dispatch(fargs, bang)
  local sub = (fargs[2] or "name"):lower()

  if sub == "name" then
    M.name_at_cursor(fargs[3], fargs[4])
  elseif sub == "search" then
    local parts = {}
    for i = 3, #fargs do
      parts[#parts + 1] = fargs[i]
    end
    M.search(table.concat(parts, " "), bang)
  elseif sub == "table" then
    M.table_open()
  elseif sub == "digraphs" then
    M.digraphs_open()
  else
    notify.error(("unknown unicode sub-action %q. Valid: name, search, table, digraphs"):format(sub))
  end
end

return M
