-- TESTS/picker_engine_spec.lua — insert picker: engine selection.
--
-- picker_spec.lua covers the two `vim.ui.select` fallbacks, which is what this
-- harness reaches on its own: neither telescope.nvim nor fzf-lua is on the
-- runtimepath. Here both are stood up as doubles in `package.loaded` -- the
-- seam `pcall(require, ...)` looks at -- so the engine matrix, the entry shape
-- each backend is handed, and the selection callback that inserts the glyph
-- are all exercised without a real picker.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local picker = require("emojis.picker")
  local config = require("emojis.config")

  local PICKS = { { "🚀", "rocket" }, { "🔥", "fire" } }

  --- A scratch buffer with the cursor between "a" and "b", so an insertion is
  --- visible as an exact resulting line.
  local function target()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    return buf
  end

  local function line_of(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  end

  -- --------------------------------------------------------- telescope double
  --- Install a fake telescope that immediately "selects" pick number `idx`.
  ---@param idx integer
  ---@return table seen  what the picker handed the backend
  local function fake_telescope(idx)
    local seen = {}
    local selected

    local select_default = {
      replace = function(_, fn)
        seen.on_select = fn
      end,
    }

    package.loaded["telescope.finders"] = {
      new_table = function(opts)
        seen.results = opts.results
        seen.entry = opts.entry_maker(opts.results[idx])
        selected = seen.entry
        return { _finder = true }
      end,
    }
    package.loaded["telescope.config"] = {
      values = {
        generic_sorter = function()
          return { _sorter = true }
        end,
      },
    }
    package.loaded["telescope.actions"] = {
      select_default = select_default,
      close = function(bufnr)
        seen.closed = bufnr
      end,
    }
    package.loaded["telescope.actions.state"] = {
      get_selected_entry = function()
        return selected
      end,
    }
    package.loaded["telescope.pickers"] = {
      new = function(_, opts)
        seen.opts = opts
        opts.finder = opts.finder
        return {
          find = function()
            seen.found = true
            opts.attach_mappings(4242, nil)
            seen.on_select()
          end,
        }
      end,
    }
    return seen
  end

  local function drop_telescope()
    for _, name in ipairs({
      "telescope.pickers",
      "telescope.finders",
      "telescope.config",
      "telescope.actions",
      "telescope.actions.state",
    }) do
      package.loaded[name] = nil
    end
  end

  --- Install a fake fzf-lua that immediately runs its default action on item
  --- number `idx`.
  ---@param idx integer
  ---@return table seen
  local function fake_fzf(idx)
    local seen = {}
    package.loaded["fzf-lua"] = {
      fzf_exec = function(items, opts)
        seen.items = items
        seen.prompt = opts.prompt
        opts.actions["default"]({ items[idx] })
      end,
    }
    return seen
  end

  -- ------------------------------------------------------------- no picks
  do
    config.setup({})
    config.get().picks = {}
    local said = H.notices(function()
      picker.insert()
    end)
    eq(said.warn[1], "no emojis configured for the picker", "insert: an empty catalog is reported")
    config.setup({})
  end

  -- ------------------------------------------------------------- telescope
  do
    config.setup({ picks = PICKS, picker = { engine = "telescope" } })
    local buf = target()
    local seen = fake_telescope(1)
    picker.insert()
    drop_telescope()

    ok(seen.found, "telescope: the picker was opened")
    eq(#seen.results, 2, "telescope: the finder gets the configured picks")
    eq(seen.entry.display, "🚀  rocket", "telescope: the entry display is glyph + label")
    eq(seen.entry.ordinal, "rocket", "telescope: sorting is by label, so typing the name finds it")
    eq(seen.entry.value[1], "🚀", "telescope: the entry keeps the pick itself as its value")
    eq(seen.closed, 4242, "telescope: the prompt is closed before inserting")
    eq(line_of(buf), "a🚀b", "telescope: the selected glyph lands at the cursor")
    eq(seen.opts.prompt_title, "Insert emoji", "telescope: titled")
  end

  -- ---------------------------------------------------------------- fzf-lua
  do
    config.setup({ picks = PICKS, picker = { engine = "fzf-lua" } })
    local buf = target()
    local seen = fake_fzf(2)
    picker.insert()
    package.loaded["fzf-lua"] = nil

    eq(#seen.items, 2, "fzf-lua: gets one display line per pick")
    eq(seen.items[2], "🔥  fire", "fzf-lua: display is glyph + label")
    eq(seen.prompt, "Insert emoji> ", "fzf-lua: prompted")
    eq(line_of(buf), "a🔥b", "fzf-lua: selection is mapped back by display, not by parsing")
  end

  -- An unknown display (a backend handing back something that was never
  -- offered) inserts nothing rather than guessing.
  do
    config.setup({ picks = PICKS, picker = { engine = "fzf-lua" } })
    local buf = target()
    package.loaded["fzf-lua"] = {
      fzf_exec = function(_, opts)
        opts.actions["default"]({ "something else entirely" })
        opts.actions["default"](nil)
      end,
    }
    picker.insert()
    package.loaded["fzf-lua"] = nil
    eq(line_of(buf), "ab", "fzf-lua: an unknown selection inserts nothing")
  end

  -- ------------------------------------------------------------------ auto
  -- "auto" tries telescope first, then fzf-lua.
  do
    config.setup({ picks = PICKS, picker = { engine = "auto" } })
    local buf = target()
    local tele = fake_telescope(1)
    local fzf = fake_fzf(1)
    picker.insert()
    drop_telescope()
    package.loaded["fzf-lua"] = nil

    ok(tele.found, "auto: telescope wins when both are installed")
    eq(fzf.items, nil, "auto: fzf-lua is not consulted")
    eq(line_of(buf), "a🚀b", "auto: the glyph still reaches the buffer")
  end

  do
    config.setup({ picks = PICKS, picker = { engine = "auto" } })
    local buf = target()
    local fzf = fake_fzf(2)
    picker.insert()
    package.loaded["fzf-lua"] = nil

    ok(fzf.items ~= nil, "auto: falls through to fzf-lua without telescope")
    eq(line_of(buf), "a🔥b", "auto: ... and inserts through it")
  end

  -- -------------------------------------------------- explicit engine misses
  -- `engine = "select"` must not reach an installed backend ...
  do
    config.setup({ picks = PICKS, picker = { engine = "select" } })
    local buf = target()
    local tele = fake_telescope(1)
    local real_select = vim.ui.select
    vim.ui.select = function(items, _, on_choice)
      eq(#items, 2, "select: the fallback gets the configured picks")
      on_choice(items[1], 1)
    end
    picker.insert()
    vim.ui.select = real_select
    drop_telescope()

    eq(tele.found, nil, "select: an installed telescope is deliberately skipped")
    eq(line_of(buf), "a🚀b", "select: inserted through vim.ui.select")
  end

  -- ... and an engine that is named but not installed degrades to the
  -- fallback rather than doing nothing.
  do
    config.setup({ picks = PICKS, picker = { engine = "telescope" } })
    local buf = target()
    local real_select = vim.ui.select
    vim.ui.select = function(items, _, on_choice)
      on_choice(items[2], 2)
    end
    picker.insert()
    vim.ui.select = real_select
    eq(line_of(buf), "a🔥b", "telescope requested but missing: falls back to vim.ui.select")
  end

  config.setup({})
end
