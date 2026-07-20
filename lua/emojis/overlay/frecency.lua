---@module 'emojis.overlay.frecency'
---@brief Usage store that reorders the overlay's curated picks by frecency.
---@description
--- The overlay starts from a curated, config-owned list (`overlay.picks`) so a
--- fresh install is immediately useful and deterministic. This module only ever
--- *reorders* that list — it never adds or removes entries, so a user who pins
--- a set of glyphs keeps exactly those glyphs, just sorted by how they actually
--- use them.
---
--- Scoring is count with exponential recency decay (`HALF_LIFE_DAYS`): a glyph
--- used twice today outranks one used three times last month, but a long-time
--- favourite is not displaced by a single accidental pick. Ties fall back to the
--- curated order, which keeps the grid stable frame-to-frame instead of
--- shuffling under the cursor.
---
--- Persistence is a single JSON file under `stdpath("data")`. Every read and
--- write is guarded: a missing, unreadable, or corrupt file degrades to "no
--- usage recorded yet" rather than erroring, because losing a usage histogram
--- must never break emoji insertion.

local uv = vim.uv or vim.loop

local M = {}

---@type number  Days after which a single use counts half as much.
local HALF_LIFE_DAYS = 30

---@type number  Seconds per day, for decay arithmetic.
local DAY = 86400

---@type table<string, {count: integer, last: integer}>|nil  Lazily loaded store.
local _store = nil

---@type string|nil  Cached resolved path.
local _path = nil

---Absolute path of the persisted store.
---@return string
function M.path()
  if not _path then
    _path = table.concat({ vim.fn.stdpath("data"), "emojis.nvim", "frecency.json" }, "/")
  end
  return _path
end

---Read the whole file, or nil if it does not exist / cannot be read.
---@param path string
---@return string|nil
local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  local data = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  return data
end

---Load the store from disk (once per session).
---@return table<string, {count: integer, last: integer}>
local function load()
  if _store then
    return _store
  end

  _store = {}

  local data = read_file(M.path())
  if not data or data == "" then
    return _store
  end

  local ok, decoded = pcall(vim.json.decode, data)
  if not ok or type(decoded) ~= "table" then
    return _store
  end

  -- Accept only well-formed entries; a hand-edited or truncated file must not
  -- poison scoring with nil/NaN arithmetic later.
  for glyph, entry in pairs(decoded) do
    if type(glyph) == "string" and type(entry) == "table" and type(entry.count) == "number" then
      _store[glyph] = { count = entry.count, last = type(entry.last) == "number" and entry.last or 0 }
    end
  end

  return _store
end

---Persist the store. Best-effort: failures are silent by design (see module doc).
---@return nil
local function save()
  if not _store then
    return
  end

  local path = M.path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

  local ok, encoded = pcall(vim.json.encode, _store)
  if not ok then
    return
  end

  local fd = uv.fs_open(path, "w", 420)
  if not fd then
    return
  end
  uv.fs_write(fd, encoded, 0)
  uv.fs_close(fd)
end

---Redirect the store (tests, or a user who wants it elsewhere). Drops anything
---already loaded so the next access reads the new location.
---@param path string
---@return nil
function M.set_path(path)
  _path = path
  _store = nil
end

---Record one use of `glyph` and persist. A no-op when `overlay.frecency` is
---off, so opting out of the feature also opts out of the disk write — users who
---disable it should not find a usage file in their data dir.
---@param glyph string
---@return nil
function M.record(glyph)
  if type(glyph) ~= "string" or glyph == "" then
    return
  end
  if not require("emojis.config").get().overlay.frecency then
    return
  end

  local store = load()
  local entry = store[glyph]
  if entry then
    entry.count = entry.count + 1
    entry.last = os.time()
  else
    store[glyph] = { count = 1, last = os.time() }
  end

  save()
end

---Frecency score for one glyph (0 when never used).
---@param glyph string
---@param now integer
---@return number
local function score(glyph, now)
  local entry = load()[glyph]
  if not entry then
    return 0
  end
  local age_days = math.max(0, (now - (entry.last or 0)) / DAY)
  return entry.count * 0.5 ^ (age_days / HALF_LIFE_DAYS)
end

---Return `picks` reordered by descending frecency, curated order breaking ties.
---The input is never mutated.
---@param picks Emojis.Config.PickEntry[]
---@return Emojis.Config.PickEntry[]
function M.sort(picks)
  local now = os.time()

  ---@type {entry: Emojis.Config.PickEntry, score: number, idx: integer}[]
  local ranked = {}
  for i = 1, #picks do
    ranked[i] = { entry = picks[i], score = score(picks[i][1], now), idx = i }
  end

  table.sort(ranked, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.idx < b.idx
  end)

  local out = {}
  for i = 1, #ranked do
    out[i] = ranked[i].entry
  end
  return out
end

---Drop all recorded usage (in memory and on disk).
---@return nil
function M.reset()
  _store = {}
  save()
end

---Testing seam: force the next access to re-read from disk.
---@return nil
function M._invalidate()
  _store = nil
end

return M
