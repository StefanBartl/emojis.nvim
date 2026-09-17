-- TESTS/health_spec.lua — :checkhealth emojis.
--
-- `vim.health` is replaced with a recorder, so each check is asserted on the
-- level it reports at (ok / warn / error / info) rather than on the text of a
-- rendered report. Every optional dependency is then driven from both sides:
-- present as a double in `package.loaded`, and absent -- which is the point of
-- a health check, and the only way to reach half of these branches on a
-- machine that happens to have (or not have) ripgrep, telescope or which-key.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local health = require("emojis.health")
  local config = require("emojis.config")

  require("emojis").setup({}) -- a no-op if an earlier spec already ran it
  config.setup({})

  --- Run `:checkhealth emojis` against a recorder.
  ---@return {start: string[], ok: string[], warn: string[], error: string[], info: string[], raised: string|nil}
  local function report()
    local rec = { start = {}, ok = {}, warn = {}, error = {}, info = {} }
    local real = vim.health
    vim.health = {
      start = function(name)
        rec.start[#rec.start + 1] = name
      end,
      ok = function(msg)
        rec.ok[#rec.ok + 1] = msg
      end,
      warn = function(msg)
        rec.warn[#rec.warn + 1] = msg
      end,
      error = function(msg)
        rec.error[#rec.error + 1] = msg
      end,
      info = function(msg)
        rec.info[#rec.info + 1] = msg
      end,
    }
    local called_ok, err = pcall(health.check)
    vim.health = real
    if not called_ok then
      rec.raised = tostring(err)
    end
    return rec
  end

  --- True when any recorded message at `level` contains `needle`.
  ---@param rec table
  ---@param level string
  ---@param needle string
  ---@return boolean
  local function said(rec, level, needle)
    for _, msg in ipairs(rec[level]) do
      if tostring(msg):find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  --- Run `fn` with `package.loaded[name]` set to a double.
  ---@param name string
  ---@param double table
  ---@param fn fun(): nil
  local function with_module(name, double, fn)
    local real = package.loaded[name]
    package.loaded[name] = double
    local called_ok, err = pcall(fn)
    package.loaded[name] = real
    if not called_ok then
      error(err, 0)
    end
  end

  -- ------------------------------------------------------- the baseline run
  do
    local rec = report()
    eq(rec.raised, nil, "check: runs to completion")
    eq(rec.start[1], "emojis", "check: opens its own section")
    ok(said(rec, "ok", "Neovim >= 0.9"), "check: the Neovim version gate")
    ok(said(rec, "ok", "usercmd.composer available"), "check: lib.nvim's composer is the hard dependency")
    ok(said(rec, "ok", "ui.kit available"), "check: ui.kit powers the overlay")
    ok(said(rec, "ok", "vim.ui.select is available"), "check: the picker fallback")
    ok(said(rec, "ok", "vim.system available"), "check: the async cwd search")
    ok(said(rec, "ok", "plugin loaded"), "check: the load guard, set by an earlier spec's setup()")
    ok(said(rec, "info", "keymaps.preset disabled"), "check: the preset is off by default")
  end

  -- ------------------------------------------------------- the picker engines
  do
    with_module("telescope.pickers", { _double = true }, function()
      local rec = report()
      ok(said(rec, "ok", "telescope.nvim found"), "check: telescope is reported when installed")
      ok(said(rec, "ok", "picker.engine = auto"), "check: ... together with the configured engine")
    end)

    with_module("fzf-lua", { _double = true }, function()
      local rec = report()
      ok(said(rec, "ok", "fzf-lua found"), "check: fzf-lua is reported when telescope is absent")
    end)

    local rec = report()
    ok(said(rec, "info", "neither telescope.nvim nor fzf-lua found"), "check: with neither, the fallback is noted")
  end

  -- -------------------------------------------------------------- ripgrep
  do
    local real_exec = vim.fn.executable
    vim.fn.executable = function()
      return 1
    end
    local present = report()
    vim.fn.executable = function()
      return 0
    end
    local absent = report()
    vim.fn.executable = real_exec

    ok(said(present, "ok", "found on PATH"), "check: ripgrep present")
    ok(said(absent, "warn", "not found"), "check: ripgrep missing is a warning, not an error")
    ok(said(absent, "warn", "cwd will not work"), "check: ... naming the feature that stops working")
  end

  -- A configured `search.cmd` is what gets probed, not a hard-coded "rg".
  do
    config.setup({ search = { cmd = "emojis-nvim-no-such-tool" } })
    local rec = report()
    ok(said(rec, "warn", "emojis-nvim-no-such-tool"), "check: the configured search command is the one probed")
    config.setup({})
  end

  -- ---------------------------------------------------------- optional bits
  do
    with_module("which-key", { _double = true }, function()
      local rec = report()
      ok(said(rec, "ok", "which-key found"), "check: which-key is reported when installed")
    end)
    local rec = report()
    ok(said(rec, "info", "which-key not installed"), "check: ... and is only informational when absent")

    with_module("cascade", { _double = true }, function()
      local with = report()
      ok(said(with, "info", "cascade.nvim found"), "check: cascade is purely informational when present")
      eq(#with.error, 0, "check: cascade never affects this plugin's health")
    end)
    ok(said(report(), "info", "cascade.nvim not found"), "check: ... and when absent, it points at the docs")
  end

  -- ------------------------------------------------- state-dependent checks
  do
    config.setup({ keymaps = { preset = true } })
    ok(said(report(), "ok", "keymaps.preset enabled"), "check: an enabled preset lists the keys it binds")
    config.setup({})

    local guard = vim.g.loaded_emojis
    vim.g.loaded_emojis = nil
    ok(said(report(), "info", "plugin guard not set"), "check: an unconfigured plugin is reported as such")
    vim.g.loaded_emojis = guard
  end

  do
    local real_system = vim.system
    ---@diagnostic disable-next-line: cast-local-type
    vim.system = nil
    local rec = report()
    vim.system = real_system
    ok(said(rec, "info", "falling back to jobstart"), "check: an older Neovim is told which transport it gets")
  end

  -- ------------------------------------------------------- ui.kit missing
  do
    local loaded, preload = package.loaded["ui.kit"], package.preload["ui.kit"]
    package.loaded["ui.kit"] = nil
    package.preload["ui.kit"] = function()
      error("ui.kit not installed (test stub)")
    end
    local rec = report()
    package.loaded["ui.kit"], package.preload["ui.kit"] = loaded, preload

    ok(said(rec, "warn", "overlay unavailable"), "check: a missing ui.nvim degrades to 'no overlay'")
    eq(#rec.error, 0, "check: ... and is a warning rather than an error")
  end

  -- ------------------------------------------------------------ regression
  -- The composer is the one hard dependency, and its absence is reported as
  -- an error. The last line of the check used to call `composer.checkhealth()`
  -- unconditionally, so on the machine that needs that message most, the
  -- report raised right after emitting it -- `:checkhealth` renders the error
  -- it caught, and the earlier findings of this section were lost. It is
  -- guarded now, like every other optional dependency this same check probes.
  do
    local name = "lib.nvim.bindings.usercmd.composer"
    local loaded, preload = package.loaded[name], package.preload[name]
    package.loaded[name] = nil
    package.preload[name] = function()
      error("lib.nvim not installed (test stub)")
    end
    local rec = report()
    package.loaded[name], package.preload[name] = loaded, preload

    ok(said(rec, "error", "will fail to register"), "check: a missing composer is reported as an error")
    eq(rec.raised, nil, "...and the report completes instead of raising on the same missing module")
  end

  config.setup({})
end
