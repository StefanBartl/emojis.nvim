-- TESTS/commands_dispatch_spec.lua — :Emojis dispatch, validation and completion.
--
-- commands_spec.lua drives the actions that mutate a buffer end to end; this
-- one covers the layer above them: which route each `[action] [scope]` pair
-- reaches, the two validation refusals, the NO_SCOPE bypass, the range
-- precedence, and what the composer completes at each position.
--
-- The leaf entry points (picker/overlay/search) are replaced with recorders
-- for the dispatch cases -- what is under test here is that the right one is
-- called with the right arguments, and each has its own spec for the rest.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("emojis.config")

  require("emojis").setup({})
  config.setup({})

  --- Replace `mod[key]` with a recorder for the duration of `fn`.
  ---@param mod table
  ---@param key string
  ---@param fn fun(record: table[]): nil
  local function recording(mod, key, fn)
    local real = mod[key]
    local calls = {}
    mod[key] = function(...)
      calls[#calls + 1] = { ... }
    end
    local called_ok, err = pcall(fn, calls)
    mod[key] = real
    if not called_ok then
      error(err, 0)
    end
  end

  -- ------------------------------------------------------------- validation
  do
    local said = H.notices(function()
      vim.cmd("Emojis clear nowhere")
    end)
    ok(said.error[1] ~= nil, "unknown scope: refused")
    ok(said.error[1]:find('unknown scope "nowhere"', 1, true) ~= nil, "unknown scope: names the offending token")
    ok(said.error[1]:find("word, line, visual, %, cwd", 1, true) ~= nil, "unknown scope: lists the valid ones")
  end

  -- The scope argument is a soft STRING (a completion hint), not a composer
  -- enum, precisely so that a NO_SCOPE action can still ignore a garbage
  -- second token instead of being rejected before dispatch.
  do
    recording(require("emojis.picker"), "insert", function(calls)
      local said = H.notices(function()
        vim.cmd("Emojis insert garbage")
      end)
      eq(#calls, 1, "insert: dispatches despite a second token that is not a scope")
      eq(#said.error, 0, "insert: ... and nothing is refused")
    end)
  end

  -- ---------------------------------------------------------------- routing
  do
    recording(require("emojis.overlay"), "open", function(calls)
      vim.cmd("Emojis overlay")
      eq(calls[1][1], nil, "overlay: no mode means the configured default")
      vim.cmd("Emojis overlay list")
      eq(calls[2][1], "list", "overlay: the second positional is a mode, not a scope")
      vim.cmd("Emojis overlay GRID_KEYS")
      eq(calls[3][1], "grid_keys", "overlay: the mode is lowercased")
      eq(#calls, 3, "overlay: one call per invocation")
    end)
  end

  do
    recording(require("emojis.nav"), "first", function(calls)
      vim.cmd("Emojis first")
      eq(#calls, 1, "first: routed to nav")
    end)
    recording(require("emojis.nav"), "next", function(calls)
      vim.cmd("Emojis next")
      eq(calls[1][1], nil, "next: no count means one step")
      vim.cmd("Emojis next 3")
      eq(calls[2][1], 3, "next: the positional arrives as a number")
    end)
  end

  -- cwd is the one scope that does not resolve to a buffer range: it hands
  -- over to the async search, with every argument after the scope keyword
  -- becoming an extra --glob.
  do
    recording(require("emojis.search"), "run", function(calls)
      vim.cmd("Emojis list cwd")
      eq(calls[1][1], "list", "cwd: the action is forwarded")
      eq(#calls[1][2], 0, "cwd: no extra globs by default")
      eq(calls[1][3], false, "cwd: the bang is forwarded as false")

      vim.cmd("Emojis count cwd *.md *.txt")
      eq(calls[2][1], "count", "cwd: the action is forwarded")
      eq(table.concat(calls[2][2], ","), "*.md,*.txt", "cwd: every trailing argument becomes a glob")

      vim.cmd("Emojis! clear cwd")
      eq(calls[3][3], true, "cwd: the bang forces --no-ignore for this call")
    end)
  end

  -- --------------------------------------------------- scope -> buffer range
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀", "b 🔥", "c ⭐" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    vim.cmd("Emojis clear line")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- "b " and not "b": the space-collapse rule only applies to an emoji with
    -- a space on BOTH sides, and this one ends the line (see core.ops).
    eq(lines[2], "b ", "line scope: only the cursor line")
    eq(lines[1], "a 🚀", "line scope: neighbours untouched")

    -- An explicit Vim range always wins over the scope keyword.
    vim.cmd("1,1Emojis clear %")
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "a ", "range: overrides the scope keyword")
    eq(vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1], "c ⭐", "range: the rest of the buffer is untouched")
  end

  -- A bare `:Emojis` is the default route: clear, in the configured scope.
  do
    config.setup({ default_scope = "line" })
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep 🚀", "cursor 🔥" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    vim.cmd("Emojis")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "cursor ", "bare :Emojis: clears in the configured default scope")
    eq(lines[1], "keep 🚀", "bare :Emojis: ... and only there")
    config.setup({})
  end

  -- count/list route to their own handlers rather than to `edit`.
  do
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b ⭐" })
    local said = H.notices(function()
      vim.cmd("Emojis count %")
    end)
    eq(said.info[1], "Found 2 emojis in 1 line", "count: routed with the whole-buffer scope")
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "a 🚀 b ⭐", "count: never mutates")

    said = H.notices(function()
      vim.cmd("Emojis list %")
    end)
    vim.cmd("cclose")
    eq(#vim.fn.getqflist(), 2, "list: routed into the quickfix list")
    eq(said.info[1], "Found 2 emojis -> quickfix", "list: reports what it found")
  end

  -- `toggle`'s second positional is a checkbox set name, and its line range
  -- comes from an explicit Vim range (defaulting to the cursor line) -- never
  -- from the whole buffer, which would flip every box in the file.
  do
    config.setup({})
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a", "🔴 b", "🔲 c" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    vim.cmd("Emojis toggle")
    eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "✅ a", "toggle: the cursor line")
    eq(vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1], "🔲 c", "toggle: and nothing else")

    vim.cmd("2Emojis toggle status")
    eq(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1], "🟡 b", "toggle: a range picks the line, the argument picks the set")

    local said = H.notices(function()
      vim.cmd("Emojis toggle nosuchset")
    end)
    ok(said.error[1]:find("unknown checkbox set", 1, true) ~= nil, "toggle: an unknown set name is refused")
  end

  -- ------------------------------------------------------------- completion
  do
    local function completes(line)
      return table.concat(vim.fn.getcompletion(line, "cmdline"), ",")
    end

    local actions = completes("Emojis ")
    ok(actions:find("clear", 1, true) ~= nil, "completion: actions at position 1")
    ok(actions:find("unreplace", 1, true) ~= nil, "completion: every action is offered")
    eq(completes("Emojis clear "), "word,line,visual,%,cwd", "completion: scopes after a scoped action")
    eq(completes("Emojis overlay "), "grid,grid_keys,list", "completion: overlay modes instead of scopes")
    ok(completes("Emojis toggle "):find("checkbox", 1, true) ~= nil, "completion: configured checkbox sets")
  end

  -- The set names are read from the *configured* sets at registration time, so
  -- a user-defined set completes exactly like a built-in one. Registered under
  -- a second command name to avoid re-registering the one the suite uses.
  do
    local cfg = config.setup({ checkbox = { sets = { mine = { "🔲", "✅" } } }, command = "EmojisSetsProbe" })
    require("emojis.commands").register(cfg)
    eq(vim.fn.exists(":EmojisSetsProbe"), 2, "register: honours cfg.command")
    local sets = table.concat(vim.fn.getcompletion("EmojisSetsProbe toggle ", "cmdline"), ",")
    ok(sets:find("mine", 1, true) ~= nil, "completion: a user-defined checkbox set completes too")
    vim.cmd("silent! delcommand EmojisSetsProbe")
    config.setup({})
  end
end
