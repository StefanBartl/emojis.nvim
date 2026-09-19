---@module 'emojis.unicode.digraphs'
--- `:Digraphs`-equivalent, built entirely on Neovim's own `vim.fn.digraph_*`
--- API (0.9+) -- unlike the name table in `emojis.unicode.data`, this needs
--- no download or parsing of `chrisbra/unicode.vim`'s own `:digraphs`
--- output: Neovim already knows every digraph it accepts after `<C-k>`.

local M = {}

---@class Emojis.Unicode.DigraphEntry
---@field code string   the two-character digraph, e.g. "e'"
---@field char string    the character it produces

---@type Emojis.Unicode.DigraphEntry[]|nil
local all

---Every digraph Neovim knows, `code`/`char` pairs. Memoized -- the table is
---static for a given Neovim build (`:digraph_getlist(1)` includes both
--- built-in and any custom `:digraph` additions, cached from first use).
---@return Emojis.Unicode.DigraphEntry[]
function M.list()
  if all then
    return all
  end
  all = {}
  ---@type [string, string][]
  local raw = vim.fn.digraph_getlist(true)
  for i = 1, #raw do
    all[i] = { code = raw[i][1], char = raw[i][2] }
  end
  return all
end

---Every digraph code that produces `char`, e.g. "é" -> `{"e'"}`. Codepoint
---rather than a raw byte-string comparison, so composed/decomposed forms of
---the same character both match.
---@param char string  a single Unicode character
---@return string[]
function M.for_char(char)
  local entries = M.list()
  local codes = {}
  for i = 1, #entries do
    if entries[i].char == char then
      codes[#codes + 1] = entries[i].code
    end
  end
  return codes
end

---For tests: drop the memoized list (Neovim's own table cannot change
---mid-session in practice, but a test may stub `digraph_getlist`).
---@return nil
function M.reset()
  all = nil
end

return M
