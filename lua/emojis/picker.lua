---@module 'emojis.picker'
---@brief Insert an emoji at the cursor — telescope/fzf-lua if available, else vim.ui.select.
---@description
--- telescope.nvim and fzf-lua are optional soft dependencies for a live-search
--- picker over the full catalog (`config.picker.engine`); `vim.ui.select` is
--- the built-in fallback and always works. Selection is mapped back to the
--- configured picks by value, not by parsing the display string, which is
--- robust against labels that contain spaces.

local api = vim.api

local notify = require("emojis.util.notify")
local config = require("emojis.config")

local M = {}

---Insert `icon` at the cursor position in the current buffer/window.
---@param icon string
---@return nil
local function insert_at_cursor(icon)
  local win = api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then
    return
  end
  local pos = api.nvim_win_get_cursor(win)
  local row, col = pos[1], pos[2]

  local buf = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  col = math.min(col, #line)

  api.nvim_buf_set_lines(buf, row - 1, row, false, { line:sub(1, col) .. icon .. line:sub(col + 1) })
  pcall(api.nvim_win_set_cursor, win, { row, col + #icon })
end

---Try the telescope.nvim picker. Returns true if it took over.
---@param picks Emojis.Config.PickEntry[]
---@return boolean
local function try_telescope(picks)
  local ok_p, pickers = pcall(require, "telescope.pickers")
  local ok_f, finders = pcall(require, "telescope.finders")
  local ok_c, conf = pcall(require, "telescope.config")
  local ok_a, actions = pcall(require, "telescope.actions")
  local ok_s, action_state = pcall(require, "telescope.actions.state")
  if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
    return false
  end

  pickers
    .new({}, {
      prompt_title = "Insert emoji",
      finder = finders.new_table({
        results = picks,
        entry_maker = function(entry)
          return { value = entry, display = entry[1] .. "  " .. entry[2], ordinal = entry[2] }
        end,
      }),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            insert_at_cursor(selection.value[1])
          end
        end)
        return true
      end,
    })
    :find()

  return true
end

---Try the fzf-lua picker. Returns true if it took over.
---@param picks Emojis.Config.PickEntry[]
---@return boolean
local function try_fzf_lua(picks)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    return false
  end

  local items, by_display = {}, {}
  for i = 1, #picks do
    local display = picks[i][1] .. "  " .. picks[i][2]
    items[i] = display
    by_display[display] = picks[i][1]
  end

  fzf_lua.fzf_exec(items, {
    prompt = "Insert emoji> ",
    actions = {
      ["default"] = function(selected)
        local icon = selected and by_display[selected[1]]
        if icon then
          insert_at_cursor(icon)
        end
      end,
    },
  })
  return true
end

---Fallback: vim.ui.select over the configured picks.
---@param picks Emojis.Config.PickEntry[]
---@return nil
local function select_fallback(picks)
  local items = {}
  for i = 1, #picks do
    items[i] = picks[i][1] .. "  " .. picks[i][2]
  end

  vim.ui.select(items, { prompt = "Insert emoji:" }, function(_, idx)
    if not idx then
      return
    end
    local entry = picks[idx]
    if entry then
      insert_at_cursor(entry[1])
    end
  end)
end

---Open the insert picker at the cursor (telescope/fzf-lua per
---`config.picker.engine`, else vim.ui.select).
---@return nil
function M.insert()
  local picks = config.get().picks
  if type(picks) ~= "table" or #picks == 0 then
    notify.warn("no emojis configured for the picker")
    return
  end

  local engine = config.get().picker.engine

  if engine == "select" then
    select_fallback(picks)
    return
  end
  if (engine == "auto" or engine == "telescope") and try_telescope(picks) then
    return
  end
  if (engine == "auto" or engine == "fzf-lua") and try_fzf_lua(picks) then
    return
  end
  select_fallback(picks)
end

return M
