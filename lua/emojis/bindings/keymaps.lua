---@module 'emojis.bindings.keymaps'
---@brief Opt-in preset keymaps (`config.keymaps.preset`).
---@description
--- Maps straight onto the public API in `emojis` — no `<Plug>` indirection.
--- which-key (if installed) labels the `<leader>e` prefix via
--- `emojis.bindings.which_key`; individual key descriptions come from each
--- mapping's `desc`.

local lib = require("emojis.util.lib")

local M = {}

---Bind the preset keymaps: <C-e> insert, <leader>ee overlay, <leader>ec count,
---<leader>el list.
---@return nil
function M.bind_preset()
  local api = require("emojis")

  lib.map({ "n", "i" }, "<C-e>", api.insert, { desc = "emojis: insert picker" })
  lib.map("n", "<leader>ee", function()
    api.overlay()
  end, { desc = "emojis: quick-insert overlay" })
  -- Also in visual mode: the checkbox actions are range-aware, so `<leader>et`
  -- over a selection ticks a whole block.
  lib.map({ "n", "x" }, "<leader>et", function()
    api.toggle()
  end, { desc = "emojis: toggle checkbox" })

  lib.map("n", "<leader>ec", api.count, { desc = "emojis: count buffer" })
  lib.map("n", "<leader>el", function()
    local scope_m = require("emojis.core.scope")
    local target = scope_m.resolve("%", 0, 0, 0)
    if target then
      require("emojis.actions").list(target)
    end
  end, { desc = "emojis: list buffer" })
end

return M
