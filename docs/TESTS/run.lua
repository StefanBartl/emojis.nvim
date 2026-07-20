-- docs/TESTS/run.lua — headless test runner for emojis.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
-- or:
--   nvim --headless -u NONE -c "set rtp+=." -l docs/TESTS/run.lua
--
-- Loads every *_spec.lua in this directory, runs it against the shared
-- harness, prints a per-spec result and exits non-zero on the first failing
-- spec (so it is CI-friendly).

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local H = dofile(dir .. "harness.lua")

-- Any spec that inserts a glyph records it for the overlay's frecency ordering.
-- Redirect that store into a temp file first, so running the suite never
-- mutates the developer's real usage history under stdpath("data").
require("emojis.overlay.frecency").set_path(vim.fn.tempname() .. "-emojis-frecency.json")

-- Ordered so failures point at the smallest layer first.
local specs = {
  "patterns_spec.lua",
  "ops_spec.lua",
  "checkbox_spec.lua",
  "scope_spec.lua",
  "config_spec.lua",
  "commands_spec.lua",
  "search_spec.lua",
  "picker_spec.lua",
  "overlay_spec.lua",
}

local failed = 0
for _, name in ipairs(specs) do
  local run = dofile(dir .. name)
  local ok, err = pcall(run, H)
  if ok then
    print(("ok    %s"):format(name))
  else
    failed = failed + 1
    print(("FAIL  %s\n      %s"):format(name, tostring(err)))
  end
end

if failed > 0 then
  print(("\n%d spec(s) failed"):format(failed))
  os.exit(1)
end

print("\nEMOJIS_TESTS_OK")
