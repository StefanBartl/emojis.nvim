-- TESTS/install_spec_spec.lua — emojis' own docs/install.json.
--
-- This file is data, and data is where a typo goes unnoticed: nothing in the
-- plugin requires it, no `luacheck` run reads it, and a broken entry surfaces
-- only as a tool quietly missing from `:Lib deps show emojis.nvim`. A tool
-- that is simply absent from a report looks exactly like a tool nobody
-- declared.
--
-- So: parse the real file with the real parser, insist it validates
-- completely, and pin what it declares against what the plugin actually uses.

return function(H)
  local eq, ok = H.eq, H.ok

  local spec = require("lib.nvim.deps.spec")

  local root = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") .. "..")
  local result, err = spec.load(root .. "/docs/install.json")
  ok(result ~= nil, "docs/install.json is readable: " .. tostring(err))
  ---@cast result -nil

  -- Zero, not "few": a rejected entry is silently dropped from `tools`, so a
  -- partial parse is indistinguishable from a shorter file.
  eq(#result.errors, 0, "docs/install.json validates with no errors")

  local bins = {}
  for _, t in ipairs(result.tools) do
    bins[#bins + 1] = t.bin
    eq(
      t.required,
      false,
      t.bin .. " is optional: every scope but `cwd` works without rg, and curl is only the Unicode-name download"
    )
    ok(t.pkg.apt and t.pkg.brew and t.pkg.winget, t.bin .. " maps to apt, brew and winget")
  end
  table.sort(bins)
  eq(table.concat(bins, ","), "curl,rg", "declares exactly the two tools the plugin shells out to")

  -- The declaration is about the *default* `search.cmd`. If that default ever
  -- moves off ripgrep, the declaration has to move with it.
  eq(require("emojis.config.DEFAULTS").search.cmd, "rg", "the declared rg is the default search.cmd")
end
