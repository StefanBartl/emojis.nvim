-- TESTS/run.lua — headless test runner for emojis.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile TESTS/run.lua" -c "qa!"
-- or:
--   nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
--
-- Loads every *_spec.lua in this directory, runs it against the shared
-- harness, prints a per-spec result and exits non-zero on any failing spec
-- (so it is CI-friendly).
--
-- Everything below runs inside one top-level pcall (LLS-31): `-c "luafile"`
-- prints a traceback and moves on to the next `-c` on an uncaught error --
-- it does not fail the command, so a load-time error anywhere in here would
-- otherwise leave `os.exit(1)` never reached and the following `-c "qa!"`
-- exiting 0. A green CI run must mean the specs actually ran, not just that
-- nvim got through the command queue.
local function main()
  local dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
  local H = dofile(dir .. "harness.lua")

  -- Any spec that inserts a glyph records it for the overlay's frecency ordering.
  -- Redirect that store into a temp file first, so running the suite never
  -- mutates the developer's real usage history under stdpath("data").
  require("emojis.overlay.frecency").set_path(vim.fn.tempname() .. "-emojis-frecency.json")

  -- Ordered so failures point at the smallest layer first.
  local specs = {
    -- pure layers
    "patterns_spec.lua",
    "ops_spec.lua",
    "checkbox_spec.lua",
    "scope_spec.lua",
    "config_spec.lua",
    "config_merge_spec.lua",
    "unicode_data_spec.lua",
    "unicode_digraphs_spec.lua",
    -- buffer-facing layers
    "insert_spec.lua",
    "nav_spec.lua",
    "util_lib_spec.lua",
    "actions_spec.lua",
    -- command / search layers
    "commands_spec.lua",
    "commands_dispatch_spec.lua",
    "search_spec.lua",
    "search_run_spec.lua",
    "unicode_spec.lua",
    -- UI layers
    "picker_spec.lua",
    "picker_engine_spec.lua",
    "frecency_spec.lua",
    "overlay_spec.lua",
    "overlay_modes_spec.lua",
    -- wiring
    "api_spec.lua",
    "bindings_spec.lua",
    "health_spec.lua",
    "install_spec_spec.lua",
  }

  -- Fail loudly if a spec file exists on disk but is not in the list above
  -- (LLS-31): the header comment above claims "every *_spec.lua", and a
  -- newly added spec silently never running would otherwise read as green.
  do
    local listed = {}
    for _, name in ipairs(specs) do
      listed[name] = true
    end
    local found = vim.fn.glob(dir .. "*_spec.lua", false, true)
    for _, path in ipairs(found) do
      local name = path:match("([^/\\]+)$")
      if name and not listed[name] then
        error(("TESTS/run.lua: %s exists on disk but is not registered in the specs list"):format(name), 0)
      end
    end
  end

  local failed, total = 0, 0
  for _, name in ipairs(specs) do
    H.checks = 0
    -- `dofile` (loading the spec) and calling it are both inside this pcall:
    -- a load-time error in one spec must count as that spec failing, not
    -- abort the whole run before `failed`/`os.exit(1)` are ever reached.
    local ok, err = pcall(function()
      local run = dofile(dir .. name)
      run(H)
    end)
    total = total + H.checks
    if ok then
      print(("ok    %-28s %4d checks"):format(name, H.checks))
    else
      failed = failed + 1
      print(("FAIL  %s\n      %s"):format(name, tostring(err)))
    end
  end

  if failed > 0 then
    print(("\n%d spec(s) failed (%d checks ran)"):format(failed, total))
    os.exit(1)
  end

  print(("\n%d specs, %d checks"):format(#specs, total))
  print("EMOJIS_TESTS_OK")
end

local ok, err = pcall(main)
if not ok then
  print(("FATAL: %s"):format(tostring(err)))
  os.exit(1)
end
