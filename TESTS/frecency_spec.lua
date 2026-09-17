-- TESTS/frecency_spec.lua — the usage store behind the overlay's ordering.
--
-- overlay_spec.lua covers the ordering as the overlay sees it; this one covers
-- the store itself: where it lives, what it writes, the decay arithmetic, and
-- above all its degradation contract -- "a missing, unreadable, or corrupt
-- file degrades to 'no usage recorded yet' rather than erroring, because
-- losing a usage histogram must never break emoji insertion" (module doc).
--
-- Every case redirects the store into a temp file first. The path run.lua set
-- is restored at the end, so the specs after this one keep writing there and
-- never touch the developer's real history.

return function(H)
  local eq, ok = H.eq, H.ok
  local frecency = require("emojis.overlay.frecency")
  local config = require("emojis.config")

  config.setup({})

  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local suite_path = frecency.path()
  local n = 0

  --- A fresh store file path (not created), and the store pointed at it.
  ---@param contents string|nil  written first, when given
  ---@return string path
  local function store_at(contents)
    n = n + 1
    local path = dir .. "/store" .. n .. ".json"
    if contents ~= nil then
      vim.fn.writefile({ contents }, path)
    end
    frecency.set_path(path)
    return path
  end

  local PICKS = { { "✅", "white_check_mark" }, { "🚀", "rocket" }, { "🔥", "fire" } }

  local function order_of(picks)
    local out = {}
    for i, entry in ipairs(frecency.sort(picks)) do
      out[i] = entry[1]
    end
    return table.concat(out)
  end

  -- ------------------------------------------------------------------- path
  -- The default location, on a module instance that run.lua has not redirected.
  do
    local real = package.loaded["emojis.overlay.frecency"]
    package.loaded["emojis.overlay.frecency"] = nil
    local fresh = require("emojis.overlay.frecency")
    local path = fresh.path()
    package.loaded["emojis.overlay.frecency"] = real

    ok(path:find(vim.fn.stdpath("data"), 1, true) == 1, "path: lives under stdpath('data')")
    ok(path:find("emojis.nvim", 1, true) ~= nil, "path: in the plugin's own directory")
    ok(path:match("frecency%.json$") ~= nil, "path: named frecency.json")
    eq(fresh.path(), path, "path: memoized")
  end

  -- ------------------------------------------------------------- persistence
  do
    local path = store_at(nil)
    eq(vim.fn.filereadable(path), 0, "record: no file before the first use")

    frecency.record("🚀")
    frecency.record("🚀")
    frecency.record("🔥")
    eq(vim.fn.filereadable(path), 1, "record: the store is written on the first use")

    local decoded = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    eq(decoded["🚀"].count, 2, "record: repeated use increments the count")
    eq(decoded["🔥"].count, 1, "record: a second glyph gets its own entry")
    ok(decoded["🚀"].last >= os.time() - 60, "record: the timestamp is now")

    -- A new session reads it back: set_path drops the in-memory store, so the
    -- ordering below can only come from the file.
    frecency.set_path(path)
    eq(order_of(PICKS), "🚀🔥✅", "load: the store is read back from disk")
  end

  -- Nothing is recorded for a glyph that is not one.
  do
    local path = store_at(nil)
    frecency.record("")
    ---@diagnostic disable-next-line: param-type-mismatch
    frecency.record(nil)
    ---@diagnostic disable-next-line: param-type-mismatch
    frecency.record(42)
    eq(vim.fn.filereadable(path), 0, "record: a non-glyph is not recorded, and writes no file")
  end

  -- Opting out of frecency opts out of the disk write, too: a user who turns
  -- the feature off should not find a usage file in their data directory.
  do
    local path = store_at(nil)
    config.setup({ overlay = { frecency = false } })
    frecency.record("🚀")
    eq(vim.fn.filereadable(path), 0, "record: overlay.frecency = false writes nothing")
    config.setup({})
  end

  -- ------------------------------------------------------- degraded stores
  do
    store_at(nil) -- missing file
    eq(order_of(PICKS), "✅🚀🔥", "load: a missing store leaves the curated order")

    store_at("")
    eq(order_of(PICKS), "✅🚀🔥", "load: an empty store leaves the curated order")

    store_at("{ this is not json")
    eq(order_of(PICKS), "✅🚀🔥", "load: a corrupt store degrades instead of raising")

    store_at("[1, 2, 3]")
    eq(order_of(PICKS), "✅🚀🔥", "load: JSON that is not an object degrades too")

    -- Entry-level validation: only well-formed entries survive, so a
    -- hand-edited file cannot poison the scoring with nil arithmetic later.
    store_at('{"🚀": {"count": "many"}, "🔥": "nonsense", "⭐": {"count": 3, "last": 0}}')
    eq(order_of(PICKS), "✅🚀🔥", "load: malformed entries are dropped")
    eq(order_of({ { "⭐", "star" }, { "✅", "white_check_mark" } }), "⭐✅", "load: the well-formed entry survives")

    -- A missing `last` is accepted as "epoch", not as nil.
    store_at('{"🔥": {"count": 4}}')
    eq(order_of(PICKS), "🔥✅🚀", "load: an entry without a timestamp still scores")
  end

  -- -------------------------------------------------------------- scoring
  do
    local now = os.time()
    local day = 86400

    -- Count with exponential recency decay: three uses last year rank below
    -- one use today ...
    store_at(('{"🚀": {"count": 3, "last": %d}, "🔥": {"count": 1, "last": %d}}'):format(now - 365 * day, now))
    eq(order_of(PICKS), "🔥🚀✅", "score: a stale favourite decays below a fresh pick")

    -- ... but a long-standing favourite is not displaced by a single
    -- accidental pick (10 uses two weeks ago still outrank one use today).
    store_at(('{"🚀": {"count": 10, "last": %d}, "🔥": {"count": 1, "last": %d}}'):format(now - 14 * day, now))
    eq(order_of(PICKS), "🚀🔥✅", "score: recency does not erase a real favourite")

    -- Ties keep the curated order, which is what stops the grid from
    -- reshuffling under the cursor frame to frame.
    store_at(('{"🚀": {"count": 2, "last": %d}, "🔥": {"count": 2, "last": %d}}'):format(now, now))
    eq(order_of(PICKS), "🚀🔥✅", "score: equal scores fall back to the curated order")

    -- A timestamp in the future must not score above one from now (the age is
    -- clamped at 0 rather than inverting the decay).
    store_at(('{"🚀": {"count": 1, "last": %d}, "🔥": {"count": 1, "last": %d}}'):format(now + 10 * day, now))
    eq(order_of(PICKS), "🚀🔥✅", "score: a future timestamp does not out-score the present")
  end

  -- sort() only ever reorders: never adds, never drops, never mutates.
  do
    store_at('{"🔥": {"count": 5}}')
    local input = { { "✅", "white_check_mark" }, { "🚀", "rocket" }, { "🔥", "fire" } }
    local sorted = frecency.sort(input)
    eq(#sorted, 3, "sort: the entry count is preserved")
    eq(input[1][1], "✅", "sort: the input list is not reordered in place")
    eq(sorted[1], input[3], "sort: the entries themselves are passed through, not copied")
    eq(#frecency.sort({}), 0, "sort: an empty pick list stays empty")
  end

  -- --------------------------------------------------------------- reset
  do
    local path = store_at(nil)
    frecency.record("🚀")
    eq(order_of(PICKS), "🚀✅🔥", "reset: usage is recorded before the reset")
    frecency.reset()
    eq(order_of(PICKS), "✅🚀🔥", "reset: the in-memory store is cleared")
    eq(vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) ~= nil, true, "reset: the cleared store is persisted")
    frecency.set_path(path)
    eq(order_of(PICKS), "✅🚀🔥", "reset: and stays cleared when read back")
  end

  -- ------------------------------------------------------------ pinned bug
  -- BUG: `save()` calls `vim.fn.mkdir(parent, "p")` outside any pcall. When
  -- the parent cannot be created -- classically because the path already
  -- exists as a FILE -- that raises a raw E739 straight out of
  -- `frecency.record`, and therefore out of `core.insert.at_cursor`, i.e. out
  -- of every emoji insertion. Which is exactly what the module's own doc rules
  -- out: "losing a usage histogram must never break emoji insertion". Every
  -- other read and write in this module is guarded; this one is not.
  do
    local blocker = dir .. "/blocker"
    vim.fn.writefile({ "not a directory" }, blocker)
    frecency.set_path(blocker .. "/nested/frecency.json")

    local recorded_ok, err = pcall(frecency.record, "🚀")
    eq(recorded_ok, false, "BUG(mkdir): record raises instead of degrading")
    ok(tostring(err):find("E739", 1, true) ~= nil, "BUG(mkdir): ... with a raw E739")

    -- And the same escape reaches the insertion path itself.
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local inserted_ok = pcall(require("emojis.core.insert").at_cursor, "🚀")
    eq(inserted_ok, false, "BUG(mkdir): an unwritable store breaks emoji insertion")
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "🚀", "BUG(mkdir): ... after the glyph was already inserted")
  end

  frecency.set_path(suite_path)
  frecency.reset()
  vim.fn.delete(dir, "rf")
end
