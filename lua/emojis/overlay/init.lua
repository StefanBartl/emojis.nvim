---@module 'emojis.overlay'
--- Quick-insert overlay — a frecency-ordered grid of the emojis a developer reaches for most.
---
--- Three interaction modes over one shared model (`config.overlay.mode`, or a
--- per-invocation override from `:Emojis overlay <mode>`):
---
---   grid       cursor navigation only (hjkl / arrows, <CR> inserts) — default
---   grid_keys  same grid, plus a direct hotkey per cell (one keypress = insert)
---   list       one glyph per row with its shortcode, via `kit.chooser`
---
--- The grid modes are rendered here rather than delegated to a kit component
--- because the kit's chooser/select are strictly row-oriented (they block
--- horizontal motion by design), and a 2D layout is the whole point of the
--- overlay — it is what makes ~20 glyphs scannable in one glance instead of a
--- scrolling column. `list` mode, which *is* row-oriented, delegates to
--- `kit.chooser` instead of duplicating it.
---
--- The overlay closes before inserting, so the glyph lands in the window the
--- user was actually editing (see `close_then`).

local api = vim.api

local config = require("emojis.config")
local notify = require("emojis.util.notify")
local lib = require("emojis.util.lib")
local insert = require("emojis.core.insert")
local frecency = require("emojis.overlay.frecency")

local M = {}

---@type string[]  Hotkey labels for `grid_keys`, in cell order (home row first).
local HOTKEYS = {
  "a",
  "s",
  "d",
  "f",
  "g",
  "h",
  "j",
  "k",
  "l",
  ";",
  "q",
  "w",
  "e",
  "r",
  "t",
  "y",
  "u",
  "i",
  "o",
  "p",
  "z",
  "x",
  "c",
  "v",
  "b",
  "n",
  "m",
  ",",
  ".",
  "/",
}

---@type table<string, boolean>  Modes accepted by `open`.
local MODES = { grid = true, grid_keys = true, list = true }

---@type table|nil  The single live overlay (mirrors the kit's single-instance UIs).
local state = nil

---@type integer
local ns = api.nvim_create_namespace("emojis_overlay")

-- Forward declaration: `bind`'s `/`-filter closure re-opens the grid, which
-- means it references `open_grid` several hundred lines before the definition
-- below. Without this the name resolved to a (nil) global at call time and the
-- filter blew up instead of re-rendering.
---@type fun(kit: table, cfg: table, items: table[], show_keys: boolean, all: table[]|nil)
local open_grid

---Load `lib.nvim.ui.kit`, or nil when lib.nvim is too old to ship it.
---@return table|nil
---@internal
local function load_kit()
  local ok, kit = pcall(require, "lib.nvim.ui.kit")
  if ok and type(kit) == "table" then
    return kit
  end
  return nil
end

---The overlay's entries: curated picks, reordered by frecency, capped at `limit`.
---@param cfg Emojis.Config
---@return Emojis.Config.PickEntry[]
---@internal
local function entries(cfg)
  local overlay = cfg.overlay
  local picks = overlay.picks
  if type(picks) ~= "table" or #picks == 0 then
    picks = cfg.picks
  end

  local sorted = overlay.frecency and frecency.sort(picks) or picks

  local limit = math.min(overlay.limit or #sorted, #sorted)
  local out = {}
  for i = 1, limit do
    out[i] = sorted[i]
  end
  return out
end

-- #####################################################################
-- grid rendering
-- #####################################################################

---Render the grid and the byte span of every cell.
---
---Spans are captured during rendering rather than recomputed afterwards because
---emoji are multi-byte and (usually) double-width: deriving a cell's byte offset
---from its column index after the fact would need the same width assumptions
---twice, and would silently drift for any glyph that renders single-width.
---@param items Emojis.Config.PickEntry[]
---@param cols integer
---@param show_keys boolean
---@return string[] lines, {row: integer, col_start: integer, col_end: integer}[] spans
---@internal
local function render(items, cols, show_keys)
  local lines, spans = {}, {}

  local row = 0
  local line = ""
  for i = 1, #items do
    local cell = show_keys and (" " .. (HOTKEYS[i] or "·") .. " " .. items[i][1] .. " ") or ("  " .. items[i][1] .. "  ")

    spans[i] = { row = row, col_start = #line, col_end = #line + #cell }
    line = line .. cell

    if i % cols == 0 or i == #items then
      lines[row + 1] = line
      row = row + 1
      line = ""
    end
  end

  return lines, spans
end

---Paint the cursor cell.
---@return nil
---@internal
local function highlight()
  if not state or not api.nvim_buf_is_valid(state.surf.bufnr) then
    return
  end

  api.nvim_buf_clear_namespace(state.surf.bufnr, ns, 0, -1)

  local span = state.spans[state.index]
  if not span then
    return
  end
  pcall(api.nvim_buf_set_extmark, state.surf.bufnr, ns, span.row, span.col_start, {
    end_col = span.col_end,
    hl_group = "KitSelection",
  })

  -- Park the real cursor on the cell too, so terminals that show it do not
  -- contradict the highlight.
  pcall(api.nvim_win_set_cursor, state.surf.winid, { span.row + 1, span.col_start })
end

---Close the overlay, then run `fn` in the window the user came from.
---
---`vim.schedule` matters here: the insert must happen after the float is fully
---gone and focus has returned, otherwise it lands in the overlay's own scratch
---buffer.
---@param fn? fun(): nil
---@return nil
---@internal
local function close_then(fn)
  if not state then
    return
  end

  local surf = state.surf
  state = nil

  if surf and surf:is_valid() then
    surf:close()
  end

  if fn then
    vim.schedule(fn)
  end
end

---Move the grid cursor by (drow, dcol), clamped to the populated cells.
---@param drow integer
---@param dcol integer
---@return nil
---@internal
local function move(drow, dcol)
  if not state then
    return
  end

  local count, cols = #state.items, state.cols
  local idx = state.index - 1
  local row, col = math.floor(idx / cols), idx % cols

  row = row + drow
  col = col + dcol

  -- Horizontal motion wraps across rows; vertical motion clamps. Wrapping
  -- vertically too would make <Down> on the last row jump to the top, which
  -- reads as a glitch in a grid this small.
  local last_row = math.floor((count - 1) / cols)
  if col < 0 then
    col = cols - 1
    row = row - 1
  elseif col >= cols then
    col = 0
    row = row + 1
  end
  row = math.max(0, math.min(last_row, row))

  local target = row * cols + col + 1
  if target >= 1 and target <= count then
    state.index = target
  end

  highlight()
end

---Insert the glyph under the grid cursor.
---@return nil
---@internal
local function submit()
  if not state then
    return
  end
  local entry = state.items[state.index]
  if not entry then
    return
  end
  close_then(function()
    insert.at_cursor(entry[1])
  end)
end

---Bind the grid's keys on the overlay buffer.
---@param show_keys boolean
---@return nil
---@internal
local function bind(show_keys)
  -- Only ever called from `open`, with the overlay already standing up; the
  -- check is what says so to a reader who arrives here from a keymap.
  if not state then
    return
  end
  local buf = state.surf.bufnr
  local function nmap(lhs, fn)
    lib.map("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  nmap("h", function()
    move(0, -1)
  end)
  nmap("<Left>", function()
    move(0, -1)
  end)
  nmap("l", function()
    move(0, 1)
  end)
  nmap("<Right>", function()
    move(0, 1)
  end)
  nmap("k", function()
    move(-1, 0)
  end)
  nmap("<Up>", function()
    move(-1, 0)
  end)
  nmap("j", function()
    move(1, 0)
  end)
  nmap("<Down>", function()
    move(1, 0)
  end)

  nmap("<CR>", submit)
  nmap("<Esc>", function()
    close_then()
  end)
  nmap("q", function()
    close_then()
  end)

  -- Type-to-filter. `list` mode has had this via kit.chooser from the start;
  -- the grid had no way to narrow at all, so finding one glyph in a full grid
  -- meant scanning it by eye.
  --
  -- A prompt behind `/` rather than a live input line: the grid is a
  -- fixed-layout hotkey surface (in `grid_keys` every printable key is
  -- already an insert action), so it has no room for one without becoming a
  -- different widget. `/` is the obvious key for "narrow this" and is not a
  -- hotkey.
  nmap("/", function()
    local kit_mod = load_kit()
    if not kit_mod then
      return
    end
    local base = state and state.all or {}
    local show_keys_now = state and state.show_keys or false
    kit_mod.input({
      title = "filter emojis: ",
      on_submit = function(query)
        query = vim.trim(query or "")
        local kept = {}
        for _, entry in ipairs(base) do
          -- Match the label, and the glyph itself so pasting one narrows to it.
          local label = tostring(entry[2] or ""):lower()
          if query == "" or label:find(query:lower(), 1, true) or entry[1] == query then
            kept[#kept + 1] = entry
          end
        end
        if #kept == 0 then
          notify.warn(("no emoji matching %q"):format(query))
          return
        end
        -- Re-open rather than patch the buffer in place: the cell spans and
        -- the per-cell hotkeys are both derived from the item list, so
        -- rebuilding is the only way to keep all three in step.
        close_then(function()
          local cfg_now = config.get()
          open_grid(kit_mod, cfg_now, kept, show_keys_now, base)
        end)
      end,
    })
  end)

  if show_keys then
    for i = 1, #state.items do
      local key, entry = HOTKEYS[i], state.items[i]
      if key then
        nmap(key, function()
          close_then(function()
            insert.at_cursor(entry[1])
          end)
        end)
      end
    end
  end
end

---Open one of the two grid modes.
---@param kit table
---@param cfg Emojis.Config
---@param items Emojis.Config.PickEntry[]
---@param show_keys boolean
---@param all Emojis.Config.PickEntry[]|nil  # the unfiltered set, so `/` can
---       widen again from the original list rather than from what is on screen
---@return nil
---@internal
function open_grid(kit, cfg, items, show_keys, all)
  local cols = math.max(1, math.min(cfg.overlay.columns, #items))
  local lines, spans = render(items, cols, show_keys)

  local surf = kit.surface.open({
    lines = lines,
    theme = cfg.overlay.theme,
    title = cfg.overlay.title,
    enter = true,
    focusable = true,
    modifiable = false,
    nice_quit = true,
    wo = { cursorline = false, wrap = false },
  })

  if not surf then
    notify.error("could not open the overlay window")
    return
  end

  -- `all` is the unfiltered set: `/` narrows from it rather than from
  -- whatever is currently displayed, so a second filter widens instead of
  -- compounding onto the first.
  state = {
    surf = surf,
    items = items,
    all = all or items,
    show_keys = show_keys,
    spans = spans,
    cols = cols,
    index = 1,
  }

  surf:on_close(function()
    state = nil
  end)

  bind(show_keys)
  highlight()
end

---Open the row-oriented `list` mode via the kit's chooser.
---@param kit table
---@param cfg Emojis.Config
---@param items Emojis.Config.PickEntry[]
---@return nil
---@internal
local function open_list(kit, cfg, items)
  local labels = {}
  for i = 1, #items do
    labels[i] = items[i][1] .. "  :" .. items[i][2] .. ":"
  end

  kit.select({
    items = labels,
    title = cfg.overlay.title,
    theme = cfg.overlay.theme,
    on_select = function(_, idx)
      local entry = items[idx]
      if entry then
        vim.schedule(function()
          insert.at_cursor(entry[1])
        end)
      end
    end,
  })
end

-- #####################################################################
-- public
-- #####################################################################

---Open the quick-insert overlay.
---@param mode? string  "grid" | "grid_keys" | "list"; defaults to `config.overlay.mode`
---@return nil
function M.open(mode)
  local cfg = config.get()

  mode = mode or cfg.overlay.mode
  if not MODES[mode] then
    notify.error(("unknown overlay mode %q. Valid: grid, grid_keys, list"):format(tostring(mode)))
    return
  end

  -- Re-opening while already open would strand the old float (its buffer-local
  -- maps are the only way to close it).
  if state then
    close_then()
  end

  local kit = load_kit()
  if not kit then
    notify.error("the overlay needs lib.nvim.ui.kit — please update lib.nvim")
    return
  end

  local items = entries(cfg)
  if #items == 0 then
    notify.warn("no emojis configured for the overlay")
    return
  end

  if mode == "list" then
    open_list(kit, cfg, items)
  else
    open_grid(kit, cfg, items, mode == "grid_keys")
  end
end

---Close the overlay if open.
---@return nil
function M.close()
  close_then()
end

---@return boolean
function M.is_open()
  return state ~= nil and state.surf:is_valid()
end

---@type string[]  Exposed for command completion.
M.MODES = { "grid", "grid_keys", "list" }

return M
