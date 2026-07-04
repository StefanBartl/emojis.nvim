-- docs/TESTS/search_spec.lua — cwd clear/replace across files (apply_across_files).
-- Exercises the confirm-gated, on-disk file mutation directly (bypassing the
-- async rg plumbing, which docs/TESTS has no need to depend on).

return function(H)
  local eq = H.eq
  local search = require("emojis.search")

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
