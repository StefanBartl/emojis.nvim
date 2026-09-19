-- TESTS/config_merge_spec.lua — the runtime config store: merge semantics,
-- validation fallbacks, and checkbox-set resolution.
--
-- config_spec.lua covers the DEFAULTS *catalog* (picks/names staying in sync);
-- this one covers config/init.lua, the module that merges user options over it
-- and answers every later `config.get()`.
--
-- Leaves the store back on plain defaults, since the specs after this one read
-- it.

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("emojis.config")
  local DEFAULTS = require("emojis.config.DEFAULTS")

  -- ----------------------------------------------------------------- merging
  do
    local cfg = config.setup({ default_scope = "line", wrap = { prefix = "<<" } })
    eq(cfg.default_scope, "line", "setup: a user scalar wins")
    eq(cfg.wrap.prefix, "<<", "setup: a nested user key wins")
    eq(cfg.wrap.suffix, "]]", "setup: sibling defaults survive a partial nested override")
    eq(cfg.command, "Emojis", "setup: untouched defaults survive")
    eq(config.get(), cfg, "get: hands back the table setup() stored")
  end

  -- setup() is NOT cumulative: every call starts from a fresh copy of
  -- DEFAULTS, so a later setup({}) is a full reset rather than a no-op. Several
  -- specs rely on exactly that to clean up after themselves.
  do
    local cfg = config.setup({})
    eq(cfg.default_scope, "%", "setup: a second call resets, it does not accumulate")
    eq(cfg.wrap.prefix, "[[", "setup: nested values reset too")
  end

  -- DEFAULTS itself is never mutated by a setup() that overrides part of it.
  do
    config.setup({ wrap = { prefix = "%%" }, overlay = { columns = 9 } })
    eq(DEFAULTS.wrap.prefix, "[[", "setup: merges over a deep copy, DEFAULTS untouched")
    eq(DEFAULTS.overlay.columns, 5, "setup: nested DEFAULTS untouched")
    config.setup({})
  end

  -- A curated list must replace the default wholesale, never merge index-wise:
  -- "these two glyphs" has to mean exactly two, not two over the default's tail.
  do
    local cfg = config.setup({ picks = { { "🚀", "rocket" }, { "🔥", "fire" } } })
    eq(#cfg.picks, 2, "setup: user picks replace the catalog wholesale")
    eq(cfg.picks[1][2], "rocket", "setup: user picks keep their order")
    ok(#config.setup({}).picks > 50, "setup: dropping the override restores the full catalog")
  end

  -- Same rule per checkbox cycle, and for the search order.
  do
    local cfg = config.setup({
      checkbox = { sets = { checkbox = { "🔲", "✅", "❌" } }, order = { "checkbox" } },
    })
    eq(#cfg.checkbox.sets.checkbox, 3, "setup: a redefined cycle replaces the default cycle")
    eq(cfg.checkbox.sets.checkbox[3], "❌", "setup: the redefined cycle keeps its own order")
    eq(#cfg.checkbox.sets.status, 3, "setup: sets the user did not mention survive")
    eq(#cfg.checkbox.order, 1, "setup: a user order replaces the default order wholesale")
    config.setup({})
  end

  -- ------------------------------------------------------------- validation
  -- Each invalid value must degrade to the documented fallback instead of
  -- reaching the feature that reads it.
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local said = H.notices(function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      config.setup({ default_scope = "nowhere" })
    end)
    eq(config.get().default_scope, "%", "setup: an unknown default_scope falls back to %")
    eq(#said.warn, 1, "setup: the fallback is announced")
    ok(said.warn[1]:find("default_scope", 1, true) ~= nil, "setup: the warning names the offending option")
  end
  do
    local said = H.notices(function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      config.setup({ overlay = { columns = "many" } })
    end)
    eq(config.get().overlay.columns, 5, "setup: a non-numeric overlay.columns falls back to 5")
    eq(#said.warn, 1, "setup: the columns fallback is announced")
  end
  do
    -- "%" is a valid scope and must NOT be rewritten by the fallback.
    config.setup({ default_scope = "cwd" })
    eq(config.get().default_scope, "cwd", "setup: cwd is a valid default_scope")
    config.setup({})
  end

  -- Invalid scalars beyond the original three also degrade to their default
  -- (ERR-22), instead of reaching overlay/init.lua's math.min() or
  -- actions.lua's vim.defer_fn() with something that raises there instead.
  do
    local said = H.notices(function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      config.setup({ overlay = { limit = "all" } })
    end)
    eq(config.get().overlay.limit, DEFAULTS.overlay.limit, "setup: a non-numeric overlay.limit falls back to the default")
    ok(said.warn[1]:find("overlay.limit", 1, true) ~= nil, "setup: the warning names the offending option")
    config.setup({})
  end
  do
    local said = H.notices(function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      config.setup({ preview = { duration_ms = "150ms" } })
    end)
    eq(
      config.get().preview.duration_ms,
      DEFAULTS.preview.duration_ms,
      "setup: a non-numeric preview.duration_ms falls back to the default"
    )
    ok(said.warn[1]:find("preview.duration_ms", 1, true) ~= nil, "setup: the warning names the offending option")
    config.setup({})
  end
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ wrap = { prefix = 7 } })
    eq(config.get().wrap.prefix, DEFAULTS.wrap.prefix, "setup: a non-string wrap.prefix falls back to the default")
    config.setup({})
  end
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ search = { extra_args = "nope" } })
    eq(
      table.concat(config.get().search.extra_args, ","),
      table.concat(DEFAULTS.search.extra_args, ","),
      "setup: a non-table search.extra_args falls back to the default"
    )
    config.setup({})
  end

  -- ------------------------------------------------------ unknown-key checks
  -- ERR-50: an unknown key (typically a typo) is dropped BEFORE the merge,
  -- with a warning -- never silently absorbed next to the real option.
  do
    local said = H.notices(function()
      config.setup({ overlay = { colums = 3 } })
    end)
    eq(config.get().overlay.columns, 5, "setup: the real option keeps its default, untouched by the typo")
    ok(said.warn[1]:find("overlay.colums", 1, true) ~= nil, "setup: the warning names the unknown key")
    ok(said.warn[1]:find('"columns"', 1, true) ~= nil, "setup: ... and suggests the nearest known one")
    config.setup({})
  end
  do
    local said = H.notices(function()
      config.setup({ frobnicate = true })
    end)
    ok(said.warn[1]:find("frobnicate", 1, true) ~= nil, "setup: an unknown top-level key is reported")
    config.setup({})
  end

  -- `keymaps` is deliberately unvalidated here: its accepted keys are the
  -- per-action names bindings/keymaps.lua declares (insert/overlay/toggle/
  -- count/list), not a static list this module could keep in sync without
  -- drifting. A per-action override used to be misreported as an "unknown
  -- config key" and stripped before ever reaching keymap.register -- which
  -- validates against the live action registry itself, downstream.
  do
    local said = H.notices(function()
      config.setup({ keymaps = { insert = "<C-y>", count = false } })
    end)
    eq(#said.warn, 0, "setup: a per-action keymaps override is not flagged as an unknown key")
    eq(config.get().keymaps.insert, "<C-y>", "setup: ... and survives the merge unstripped")
    eq(config.get().keymaps.count, false, "setup: ... including a `false` override")
    config.setup({})
  end

  -- ------------------------------------------- get() before any setup() call
  -- A fresh module instance (the state a user who never calls setup() is in)
  -- must answer from a copy of DEFAULTS rather than from nil. Swapped in and
  -- out of package.loaded so the instance every other module already holds a
  -- reference to is the one left behind.
  do
    local real = package.loaded["emojis.config"]
    package.loaded["emojis.config"] = nil
    local fresh = require("emojis.config")
    local cfg = fresh.get()
    package.loaded["emojis.config"] = real

    eq(cfg.command, "Emojis", "get: falls back to DEFAULTS before setup()")
    ok(cfg ~= DEFAULTS, "get: the implicit config is a copy, not DEFAULTS itself")
    ok(cfg.overlay ~= DEFAULTS.overlay, "get: the copy is deep")
  end

  -- ------------------------------------------------------ checkbox_sets(name)
  do
    -- A user `sets` table is a map, so it merges *into* the defaults: naming a
    -- set redefines it, but setup() cannot remove one. The live config is
    -- therefore replaced wholesale here, to fix exactly which sets exist.
    config.setup({ checkbox = { sets = { status = { "s1" } } } })
    eq(#config.get().checkbox.sets.status, 1, "setup: a named set is redefined")
    ok(config.get().checkbox.sets.review ~= nil, "setup: the sets a user did not name are still there")

    config.setup({})
    local cb = config.get().checkbox
    cb.sets = { zulu = { "z1", "z2" }, alpha = { "a1", "a2" }, mike = { "m1" }, empty = {} }
    cb.order = { "mike", "mike", "ghost" }

    -- A named set resolves to exactly that one cycle.
    local sets, err = config.checkbox_sets("alpha")
    eq(err, nil, "checkbox_sets: a known name resolves without an error")
    eq(#sets, 1, "checkbox_sets: a named set resolves to exactly one cycle")
    eq(sets[1][1], "a1", "checkbox_sets: and it is the right one")

    -- Unknown / empty sets are reported, not silently substituted.
    local none, unknown_err = config.checkbox_sets("nope")
    eq(#none, 0, "checkbox_sets: an unknown name resolves to nothing")
    eq(unknown_err, 'unknown checkbox set "nope"', "checkbox_sets: unknown name error message")
    eq(select(2, config.checkbox_sets("empty")) ~= nil, true, "checkbox_sets: an empty set counts as unknown")

    -- nil/"" means every set: `order` first (that is what makes ambiguity
    -- resolution the user's decision), then the rest name-sorted.
    local all = config.checkbox_sets()
    eq(#all, 3, "checkbox_sets: every non-empty set, and only those")
    eq(all[1][1], "m1", "checkbox_sets: order[] comes first")
    eq(all[2][1], "a1", "checkbox_sets: unordered sets follow name-sorted")
    eq(all[3][1], "z1", "checkbox_sets: ... in a stable order")
    eq(#config.checkbox_sets(""), 3, 'checkbox_sets: "" means the same as nil')

    -- A name repeated in `order` must not duplicate the cycle, and a name in
    -- `order` with no set behind it must not become a hole.
    local names = config.checkbox_set_names()
    eq(table.concat(names, ","), "alpha,empty,mike,zulu", "checkbox_set_names: sorted, including empty ones")
  end

  config.setup({})
end
