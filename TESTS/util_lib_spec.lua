-- TESTS/util_lib_spec.lua — the guarded bridge to lib.nvim (util/lib.lua) and
-- the notify wrapper on top of it.
--
-- Every accessor there has two paths: the lib.nvim helper, and a native
-- fallback for the user who does not have it. lib.nvim IS on the runtimepath
-- in this harness (it is a hard dependency of the command layer), so the
-- fallbacks are reached by making `require` fail through `package.preload` —
-- the same trick picker_spec.lua uses for ui.kit.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok

  --- Run `fn` with `require(name)` failing, as if that module were not
  --- installed. Restores the loader and the module cache afterwards.
  ---@param name string
  ---@param fn fun(): nil
  local function without(name, fn)
    local loaded, preload = package.loaded[name], package.preload[name]
    package.loaded[name] = nil
    package.preload[name] = function()
      error(name .. " not installed (test stub)")
    end

    local called_ok, err = pcall(fn)

    package.loaded[name] = loaded
    package.preload[name] = preload
    if not called_ok then
      error(err, 0)
    end
  end

  -- Every other module of this plugin captured these two tables at load time,
  -- so the copies below are additional instances -- the cache must be put back
  -- exactly as it was, or `H.notices` would patch a table nobody calls.
  local real_lib = package.loaded["emojis.util.lib"]
  local real_notify = package.loaded["emojis.util.notify"]

  --- A fresh copy of util/lib.lua, so its memoized notifier does not leak
  --- between the cases below.
  ---@return table
  local function fresh_lib()
    package.loaded["emojis.util.lib"] = nil
    local mod = require("emojis.util.lib")
    package.loaded["emojis.util.lib"] = real_lib
    return mod
  end

  -- --------------------------------------------------------------- notifier
  do
    local lib = fresh_lib()
    local notifier = lib.notifier()
    eq(type(notifier.info), "function", "notifier: info")
    eq(type(notifier.warn), "function", "notifier: warn")
    eq(type(notifier.error), "function", "notifier: error")
    eq(type(notifier.debug), "function", "notifier: debug")
    eq(lib.notifier(), notifier, "notifier: memoized, one notifier per session")
  end

  -- Without lib.nvim.notify it degrades to a prefixed vim.notify wrapper.
  do
    without("lib.nvim.notify", function()
      local lib = fresh_lib()
      local seen = {}
      local real_vim_notify = vim.notify
      vim.notify = function(msg, level)
        seen[#seen + 1] = { msg = msg, level = level }
      end
      lib.notifier().warn("careful")
      lib.notifier().info("done")
      vim.notify = real_vim_notify

      eq(#seen, 2, "notifier fallback: both messages reached vim.notify")
      eq(seen[1].msg, "[emojis] careful", "notifier fallback: prefixed")
      eq(seen[1].level, vim.log.levels.WARN, "notifier fallback: warn level")
      eq(seen[2].level, vim.log.levels.INFO, "notifier fallback: info level")
    end)
  end

  -- util/notify.lua is the thin wrapper every module actually calls.
  do
    local seen = {}
    local real_vim_notify = vim.notify
    vim.notify = function(msg, level)
      seen[#seen + 1] = { msg = msg, level = level }
    end

    without("lib.nvim.notify", function()
      package.loaded["emojis.util.lib"] = nil
      package.loaded["emojis.util.notify"] = nil
      local fresh = require("emojis.util.notify")
      fresh.info("i")
      fresh.warn("w")
      fresh.error("e")
    end)

    package.loaded["emojis.util.lib"] = real_lib
    package.loaded["emojis.util.notify"] = real_notify
    vim.notify = real_vim_notify

    eq(require("emojis.util.notify"), real_notify, "notify: the module identity is restored for the later specs")
    eq(#seen, 3, "notify: info/warn/error all forward to the notifier")
    eq(seen[1].msg, "[emojis] i", "notify: the prefix comes from the notifier")
    eq(seen[3].level, vim.log.levels.ERROR, "notify: error maps to the ERROR level")
  end

  -- -------------------------------------------------------------- dedup_list
  do
    local lib = require("emojis.util.lib")
    local out = lib.dedup_list({ "a", "b", "a", "c", "b" })
    eq(table.concat(out, ","), "a,b,c", "dedup_list: first occurrence wins")
    eq(#lib.dedup_list({}), 0, "dedup_list: empty input")

    without("lib.lua.tables", function()
      local fallback = fresh_lib().dedup_list({ "x", "x", "y" })
      eq(table.concat(fallback, ","), "x,y", "dedup_list fallback: same result without lib.lua")
    end)
  end

  -- ------------------------------------------------------------ utf8_decode
  do
    local lib = require("emojis.util.lib")
    eq(lib.utf8_decode("🚀", 1), 0x1F680, "utf8_decode: 4-byte lead")
    eq(lib.utf8_decode("⚠️", 1), 0x26A0, "utf8_decode: 3-byte lead, VS16 ignored")
    eq(lib.utf8_decode("a", 1), 0x61, "utf8_decode: ASCII")
    eq(lib.utf8_decode("x🔥", 2), 0x1F525, "utf8_decode: honours the byte offset")

    without("lib.lua.strings.utf8", function()
      local fallback = fresh_lib()
      eq(fallback.utf8_decode("🚀", 1), 0x1F680, "utf8_decode fallback: 4-byte lead")
      eq(fallback.utf8_decode("⚠️", 1), 0x26A0, "utf8_decode fallback: 3-byte lead")
      eq(fallback.utf8_decode("a"), 0x61, "utf8_decode fallback: defaults to byte 1")
      -- A truncated lead byte has no continuation bytes to decode: the raw
      -- byte is returned rather than arithmetic on nil.
      eq(fallback.utf8_decode("\240"), 0xF0, "utf8_decode fallback: truncated sequence degrades to the byte")
    end)

    -- core.patterns.codepoint is the one caller, and it must survive a decoder
    -- that returns nothing.
    eq(require("emojis.core.patterns").codepoint(""), 0, "codepoint: an empty glyph decodes to 0")
  end

  -- -------------------------------------------------------------------- map
  do
    local lib = require("emojis.util.lib")
    local buf = H.scratch()
    local hit = 0
    lib.map("n", "<Plug>(emojis-test-lib)", function()
      hit = hit + 1
    end, { buffer = buf, desc = "emojis test map" })

    local found
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if m.lhs == "<Plug>(emojis-test-lib)" then
        found = m
      end
    end
    ok(found ~= nil, "map: the keymap is set on the buffer")

    -- The `opts.desc` is pulled out for lib.nvim's signature; whichever path
    -- ran, the description must survive onto the mapping.
    eq(found and found.desc, "emojis test map", "map: the description survives the lib.nvim call shape")

    without("lib.nvim.bindings.keymap", function()
      local fallback = fresh_lib()
      fallback.map("n", "<Plug>(emojis-test-native)", function()
        hit = hit + 1
      end, { buffer = buf })
      local native
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
        if m.lhs == "<Plug>(emojis-test-native)" then
          native = m
        end
      end
      ok(native ~= nil, "map fallback: vim.keymap.set is used without lib.nvim")
    end)
  end
end
