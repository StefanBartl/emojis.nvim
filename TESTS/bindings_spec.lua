-- TESTS/bindings_spec.lua — the binding layer: usrcmds, keymaps, autocmds.
--
-- commands_spec.lua asserts that `:Emojis` exists and that the preset is off
-- by default; this one covers the layer that decides so. The keys are declared
-- through `lib.nvim.bindings.keymap`'s registry, which makes each one an
-- individually overridable value -- moving one, dropping one, and binding none
-- are three different outcomes of the same declaration, and each is asserted
-- here against the real registry, not against a double.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local keymaps = require("emojis.bindings.keymaps")
  local config = require("emojis.config")

  config.setup({})

  --- The registry entry for one declared action.
  ---@param regs table[]
  ---@param name string
  ---@return table|nil
  local function entry(regs, name)
    for _, reg in ipairs(regs) do
      if reg.name == name then
        return reg
      end
    end
    return nil
  end

  -- -------------------------------------------------------------- declaring
  -- Declaring is not binding: with the preset off, every action is still
  -- declared (:checkhealth and the generated docs ask what EXISTS) but none of
  -- them is bound.
  do
    local regs = keymaps.bind_preset({ keymaps = { preset = false } })
    eq(#regs, 5, "bind_preset: all five actions are declared")
    for _, name in ipairs({ "insert", "overlay", "toggle", "count", "list" }) do
      ok(entry(regs, name) ~= nil, "bind_preset: " .. name .. " is declared")
      eq(entry(regs, name).bound, false, "bind_preset: " .. name .. " is not bound with preset = false")
    end
  end

  -- -------------------------------------------------------------- the preset
  do
    local regs = keymaps.bind_preset({ keymaps = { preset = true } })
    eq(entry(regs, "insert").lhs, "<C-e>", "preset: insert's default key")
    eq(entry(regs, "overlay").lhs, "<leader>ee", "preset: overlay's default key")
    eq(entry(regs, "toggle").lhs, "<leader>et", "preset: toggle's default key")
    eq(entry(regs, "count").lhs, "<leader>ec", "preset: count's default key")
    eq(entry(regs, "list").lhs, "<leader>el", "preset: list's default key")
    eq(entry(regs, "insert").bound, true, "preset: and they are actually bound")

    -- The modes are part of the declaration: insert is also an insert-mode
    -- key, and toggle is also a visual-mode one (the checkbox actions are
    -- range-aware).
    eq(table.concat(entry(regs, "insert").mode, ","), "n,i", "preset: insert is bound in normal and insert mode")
    eq(table.concat(entry(regs, "toggle").mode, ","), "n,x", "preset: toggle is bound in normal and visual mode")
    eq(entry(regs, "count").mode, "n", "preset: the rest are normal-mode only")

    ok(vim.fn.maparg("<C-e>", "n") ~= "", "preset: <C-e> reached Neovim")
    ok(vim.fn.maparg("<C-e>", "i") ~= "", "preset: ... in insert mode too")
  end

  -- ------------------------------------------------------------- overriding
  -- A single action can be moved or dropped without rebuilding the set.
  do
    local regs = keymaps.bind_preset({ keymaps = { preset = true, count = "<leader>zq", list = false } })
    eq(entry(regs, "count").lhs, "<leader>zq", "override: an action moves to the user's key")
    eq(entry(regs, "count").bound, true, "override: and is bound there")
    eq(entry(regs, "list").bound, false, "override: `false` drops one action")
    eq(entry(regs, "list").lhs, nil, "override: ... without a key of its own")
    eq(entry(regs, "overlay").lhs, "<leader>ee", "override: the others keep their defaults")

    pcall(vim.keymap.del, "n", "<leader>zq")
  end

  -- Called with no config at all, the preset's own defaults apply -- which is
  -- what the last line of keymaps.lua's doc promises a caller with no resolved
  -- config (a test) can rely on.
  do
    local regs = keymaps.bind_preset()
    eq(#regs, 5, "bind_preset(): declares the same five actions without a config")
    eq(entry(regs, "insert").default or entry(regs, "insert").lhs, "<C-e>", "bind_preset(): with the preset defaults")
  end

  -- --------------------------------------------------------------- the rhs
  -- Each declared action maps straight onto the public API, with no <Plug>
  -- indirection -- so the registry entries are also the only place those five
  -- closures are reachable from.
  do
    local regs = keymaps.bind_preset({ keymaps = { preset = true } })

    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔲 a 🚀", "b ⭐" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local said = H.notices(function()
      entry(regs, "count").rhs()
    end)
    eq(said.info[1], "Found 3 emojis in 2 lines", "rhs count: counts the whole buffer, checkbox glyph included")

    said = H.notices(function()
      entry(regs, "list").rhs()
    end)
    vim.cmd("cclose")
    eq(#vim.fn.getqflist(), 3, "rhs list: fills the quickfix list from the whole buffer")
    eq(said.info[1], "Found 3 emojis -> quickfix", "rhs list: and reports it")

    entry(regs, "toggle").rhs()
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "✅ a 🚀", "rhs toggle: cycles the cursor line's checkbox")

    local overlay = require("emojis.overlay")
    local real_open, opened = overlay.open, 0
    overlay.open = function()
      opened = opened + 1
    end
    entry(regs, "overlay").rhs()
    overlay.open = real_open
    eq(opened, 1, "rhs overlay: opens the overlay")

    local picker = require("emojis.picker")
    local real_insert, inserted = picker.insert, 0
    picker.insert = function()
      inserted = inserted + 1
    end
    entry(regs, "insert").rhs()
    picker.insert = real_insert
    eq(inserted, 1, "rhs insert: opens the picker")
  end

  -- ------------------------------------------------------------- autocmds
  -- Deliberately empty: emojis.nvim has no autocmd-driven behaviour, and the
  -- stub exists so bindings/ mirrors the shape used across the other plugins.
  do
    local before = #vim.api.nvim_get_autocmds({ event = { "BufWritePost", "BufEnter" } })
    require("emojis.bindings.autocmds").setup(config.get())
    local after = #vim.api.nvim_get_autocmds({ event = { "BufWritePost", "BufEnter" } })
    eq(after, before, "autocmds: setup() registers nothing")
  end

  -- ------------------------------------------------------------ the whole set
  -- `bindings.setup` is what `emojis.setup` calls: the command is registered
  -- unconditionally, the keymaps only as configured.
  do
    local cfg = config.setup({ command = "EmojisBindingsProbe", keymaps = { preset = false } })
    require("emojis.bindings").setup(cfg)
    eq(vim.fn.exists(":EmojisBindingsProbe"), 2, "bindings.setup: the command is registered from cfg.command")

    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a 🚀 b" })
    vim.cmd("EmojisBindingsProbe clear %")
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "a b", "bindings.setup: and the command works")

    vim.cmd("silent! delcommand EmojisBindingsProbe")
    config.setup({})
  end

  -- The keymap registry keeps the declaration around under the plugin's name,
  -- which is what :checkhealth and the docs generator read. (The registry
  -- accumulates: this suite re-declares the preset several times, so the
  -- assertion is on the names being present, not on the entry count.)
  do
    local registered = require("lib.nvim.bindings.keymap").registered("emojis")
    local names = {}
    for _, reg in ipairs(registered) do
      names[reg.name] = true
    end
    for _, name in ipairs({ "insert", "overlay", "toggle", "count", "list" }) do
      ok(names[name], "registry: " .. name .. " is retrievable under the plugin's name")
    end
  end
end
