-- TESTS/search_spec.lua — cwd clear/replace across files (apply_across_files).
-- Exercises the confirm-gated, on-disk file mutation directly (bypassing the
-- async rg plumbing, which TESTS has no need to depend on).

return function(H)
  local eq = H.eq
  local search = require("emojis.search")

  -- build_cmd: extra_args, no_ignore, and per-invocation --glob filters
  do
    local cfg = { cmd = "rg", extra_args = { "--no-heading" }, no_ignore = false }
    local cmd = search.build_cmd(cfg, nil, "/proj")
    eq(
      table.concat(cmd, " "),
      "rg --no-heading [\\x{1F000}-\\x{1FFFF}\\x{2600}-\\x{27FF}\\x{2B00}-\\x{2BFF}] /proj",
      "build_cmd: no extras"
    )

    cfg.no_ignore = true
    cmd = search.build_cmd(cfg, { "*.md" }, "/proj")
    eq(
      table.concat(cmd, " "),
      "rg --no-heading --no-ignore --glob *.md [\\x{1F000}-\\x{1FFFF}\\x{2600}-\\x{27FF}\\x{2B00}-\\x{2BFF}] /proj",
      "build_cmd: no_ignore + glob filter"
    )
  end

  -- line_collector: the two things only real streaming exposes -------------
  -- Neither transport hands over lines. A chunk can end mid-line, and
  -- `jobstart`'s list form has the same property (@see :h channel-lines).
  -- Splitting each chunk on its own cut those lines in two -- measured on
  -- 4000 lines of rg output: 4026 entries, 26 of them malformed. Those
  -- entries feed `files_of`, which is what `:Emojis clear cwd` derives the
  -- files to rewrite from, so a cut line could drop a file from a
  -- destructive operation.
  do
    local out = {}
    local c = search.line_collector(out)

    c.feed("a.txt:1:one\nb.txt:2:tw")
    eq(#out, 1, "line_collector: only the complete line is emitted")
    c.feed("o\n")
    eq(out[2], "b.txt:2:two", "line_collector: the split line is rejoined, not cut")
    c.flush()
    eq(#out, 2, "line_collector: a flush with nothing buffered adds nothing")
  end

  do
    -- Output that never ends in a newline still has a last line.
    local out = {}
    local c = search.line_collector(out)
    c.feed("only.txt:9:no trailing newline")
    eq(#out, 0, "line_collector: an unterminated line waits for more")
    c.flush()
    eq(out[1], "only.txt:9:no trailing newline", "line_collector: flush emits it")
  end

  do
    -- ripgrep reports a match from a CRLF file with the CR still attached,
    -- and `vim.system`'s text=true does not cover a function handler.
    local out = {}
    local c = search.line_collector(out)
    c.feed("a.txt:1:one\r\nb.txt:2:two\r\n")
    eq(table.concat(out, "|"), "a.txt:1:one|b.txt:2:two", "line_collector: trailing CR is stripped")
  end

  do
    -- The case that defeats normalizing each chunk on its own: the CRLF pair
    -- is torn in half, so neither chunk contains it.
    local out = {}
    local c = search.line_collector(out)
    c.feed("a.txt:1:one\r")
    c.feed("\n")
    eq(out[1], "a.txt:1:one", "line_collector: a CRLF split across chunks still strips")
  end

  do
    -- A CR inside the matched text is the file's own content, not a line
    -- ending, and has to survive.
    local out = {}
    local c = search.line_collector(out)
    c.feed("a.txt:1:mid\rdle\n")
    eq(out[1], "a.txt:1:mid\rdle", "line_collector: an interior CR is left alone")
  end

  do
    -- Blank lines carry no match and were always dropped; keep it that way.
    local out = {}
    local c = search.line_collector(out)
    c.feed("\n\na.txt:1:x\n")
    eq(table.concat(out, "|"), "a.txt:1:x", "line_collector: empty lines are skipped")
  end

  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local f1 = dir .. "/a.txt"
  local f2 = dir .. "/b.txt"
  vim.fn.writefile({ "keep 🚀 this" }, f1)
  vim.fn.writefile({ "and 🔥 that" }, f2)
  local matches = { f1 .. ":1:keep 🚀 this", f2 .. ":1:and 🔥 that" }

  -- declining the confirmation leaves every file untouched
  search.apply_across_files("clear", matches, function()
    return 2 -- "No"
  end)
  eq(vim.fn.readfile(f1)[1], "keep 🚀 this", "declined: file 1 untouched")
  eq(vim.fn.readfile(f2)[1], "and 🔥 that", "declined: file 2 untouched")

  -- accepting clears every matched file on disk
  search.apply_across_files("clear", matches, function()
    return 1 -- "Yes"
  end)
  eq(vim.fn.readfile(f1)[1], "keep this", "accepted: file 1 cleared")
  eq(vim.fn.readfile(f2)[1], "and that", "accepted: file 2 cleared")

  -- a loaded, modified buffer is skipped rather than clobbered
  local f3 = dir .. "/c.txt"
  vim.fn.writefile({ "skip 🎉 me" }, f3)
  vim.cmd("edit " .. vim.fn.fnameescape(f3))
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "skip 🎉 me (edited)" })
  eq(vim.bo[buf].modified, true, "buffer is dirty before apply")

  search.apply_across_files("clear", { f3 .. ":1:skip 🎉 me" }, function()
    return 1
  end)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "skip 🎉 me (edited)", "dirty buffer left untouched")

  vim.cmd("bwipeout! " .. buf)
  vim.fn.delete(dir, "rf")
end
