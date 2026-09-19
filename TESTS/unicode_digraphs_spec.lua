-- TESTS/unicode_digraphs_spec.lua — emojis.unicode.digraphs: a thin read
-- over Neovim's own vim.fn.digraph_getlist(), no download involved.

return function(H)
  local eq, ok = H.eq, H.ok
  local digraphs = require("emojis.unicode.digraphs")

  digraphs.reset()
  local all = digraphs.list()
  ok(#all > 0, "list: Neovim ships a non-empty built-in digraph table")

  -- "e'" -> é is one of Vim's oldest built-in digraphs; a stable anchor to
  -- assert against rather than asserting on the full list's size (which
  -- differs across Neovim builds/versions).
  local codes = digraphs.for_char("é")
  ok(vim.tbl_contains(codes, "e'"), "for_char: e' produces é")

  eq(#digraphs.for_char("\xF0\x9F\x9A\x80"), 0, "for_char: no digraph produces 🚀")

  -- reset() drops the memoized list without erroring on the next list() call.
  digraphs.reset()
  ok(#digraphs.list() > 0, "reset: list() still works after a reset")
end
