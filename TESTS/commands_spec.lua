-- TESTS/commands_spec.lua — :Emojis exists; keymaps.preset gates the preset keys.
-- The stdlib and module fields replaced below are test doubles: each one is
-- swapped for the length of a single case and restored on the next line.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch, duplicate-set-field

return function(H)
  local eq = H.eq

  package.loaded["emojis"] = nil
  package.loaded["emojis.config"] = nil
  local emojis = require("emojis")

  emojis.setup({})
  eq(vim.fn.exists(":Emojis"), 2, ":Emojis defined")

  -- preset keymaps are opt-in and off by default
  eq(vim.fn.maparg("<C-e>", "n"), "", "preset off by default: <C-e> unbound")

  -- enabling the preset binds it (setup() is idempotent, so bind directly
  -- through the bindings module to exercise the gate without a second setup())
  local cfg = require("emojis.config").setup({ keymaps = { preset = true } })
  require("emojis.bindings.keymaps").bind_preset()
  local mapping = vim.fn.maparg("<C-e>", "n")
  eq(mapping ~= "", true, "preset on: <C-e> bound")
  eq(cfg.keymaps.preset, true, "config reflects keymaps.preset = true")

  -- :Emojis unreplace restores :name: placeholders back to emojis
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "shipped :white_check_mark: today" })
    vim.cmd("Emojis unreplace %")
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    eq(line, "shipped ✅ today", "unreplace: :name: restored to emoji")
  end

  -- :Emojis first/next move the cursor without touching the buffer
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no emoji here", "one 🚀 here", "two 🔥 and ⭐ here" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    vim.cmd("Emojis first")
    local pos = vim.api.nvim_win_get_cursor(0)
    eq(pos[1], 2, "first: jumps to the line with the first emoji")

    vim.cmd("Emojis next")
    pos = vim.api.nvim_win_get_cursor(0)
    eq(pos[1], 3, "next: jumps forward to the next emoji's line")
    local line = vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1]
    eq(line:sub(pos[2] + 1, pos[2] + 4), "🔥", "next: lands exactly on the emoji")

    vim.cmd("Emojis next")
    vim.cmd("Emojis next") -- past the last emoji -> wraps back to the first
    pos = vim.api.nvim_win_get_cursor(0)
    eq(pos[1], 2, "next: wraps around to the first emoji")

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "one 🚀 here", "first/next: buffer content untouched")
  end

  -- :Emojis wrap surrounds emojis using the configured marker
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "shipped ✅ today" })
    vim.cmd("Emojis wrap %")
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    eq(line, "shipped [[✅]] today", "wrap: default [[ ]] marker applied")
  end

  -- preview.enable highlights the affected span before clear mutates it
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep 🚀 this" })
    require("emojis.config").setup({ preview = { enable = true, duration_ms = 1 } })

    -- The preview no longer blocks with vim.wait(); it sets the extmarks,
    -- returns, and clears + mutates from a vim.defer_fn callback. So we sample
    -- the extmarks synchronously right after the command (the highlight is up
    -- at that point) and then pump the loop until the mutation has landed.
    local ns = vim.api.nvim_create_namespace("emojis_preview")
    vim.cmd("Emojis clear %")
    local seen_extmark = #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}) > 0

    vim.wait(1000, function()
      return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "keep this"
    end, 5)
    require("emojis.config").setup({ preview = { enable = false } })

    eq(seen_extmark, true, "preview: extmark set on the emoji span before clearing")
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "keep this", "preview: buffer still cleared correctly")
  end

  -- ─────────────────────────────── :Emojis next [count]
  --
  -- A positional rather than a command count: `:3Emojis next` would be an
  -- address (line 3), which is not what "three emoji onward" means.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a ✅ b", "c 🚀 d", "e 🎯 f", "g" })

    local function jump(cmd)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd(cmd)
      return vim.api.nvim_win_get_cursor(0)[1]
    end

    eq(jump("Emojis next"), 1, "next: lands on the first emoji")
    eq(jump("Emojis next 2"), 2, "next 2: two emoji forward")
    eq(jump("Emojis next 3"), 3, "next 3: three emoji forward")
    -- Stepping (rather than scanning for the Nth match) is what keeps the
    -- wrap correct: five steps over three emoji comes back round to the
    -- second, not to nothing.
    eq(jump("Emojis next 5"), 2, "next 5: wraps past the last emoji")
  end

  -- ─────────────────────────────── the `!` variants
  --
  -- One bang, two actions, no ambiguity: they are disjoint. On `toggle` it
  -- steps the checkbox backward; on a cwd-scoped search it forces
  -- --no-ignore for that call only.
  do
    local actions = require("emojis.actions")
    local real, seen_dir = actions.checkbox, nil
    actions.checkbox = function(_, _, _, dir)
      seen_dir = dir
    end
    vim.cmd("Emojis toggle")
    eq(seen_dir, 1, "toggle: forward by default")
    vim.cmd("Emojis! toggle")
    eq(seen_dir, -1, "toggle!: backward — previously Lua-API only")
    actions.checkbox = real

    local search = require("emojis.search")
    local real_run, seen_ni = search.run, nil
    search.run = function(_, _, no_ignore)
      seen_ni = no_ignore
    end
    vim.cmd("Emojis clear cwd")
    eq(seen_ni, false, "cwd search: honours the configured no_ignore")
    vim.cmd("Emojis! clear cwd")
    eq(seen_ni, true, "cwd search!: forces --no-ignore")
    search.run = real_run

    -- The override must not leak into later searches.
    eq(require("emojis.config").get().search.no_ignore, false, "the bang does not mutate search.no_ignore")
  end

  -- "word" scope only clears the whitespace-delimited token under the cursor
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep 🚀done here" })
    vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- inside "🚀done"
    vim.cmd("Emojis clear word")
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    eq(line, "keep done here", "word scope: only the cursor's token is cleared")
  end
end
