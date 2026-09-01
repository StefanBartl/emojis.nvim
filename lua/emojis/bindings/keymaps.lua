---@module 'emojis.bindings.keymaps'
--- The opt-in preset keymaps, declared as named actions.
---
--- The keys used to be hard-coded here, with only `keymaps.preset` deciding
--- whether they were bound at all -- so a user who wanted four of the five had
--- to switch the preset off and rebuild the set by hand. Declaring them
--- through `lib.nvim.bindings.keymap`'s registry makes each one an
--- individually overridable value: `keymaps = { count = "<leader>x" }` moves
--- one, `count = false` drops one, and `preset = false` still binds nothing.
---
--- Maps straight onto the public API in `emojis` -- no `<Plug>` indirection.
--- which-key needs no registration for the individual keys: it reads them
--- itself and labels each from its own `desc`. Only the `<leader>e` group
--- label is outside what it can infer, and that is declared in the spec below.

local keymap = require("lib.nvim.bindings.keymap")

local M = {}

--- Declare and bind the preset's actions.
---@param cfg Emojis.Config?  nil binds the preset's own defaults with no user
---       overrides -- which is what the last line does with it, and what a
---       caller that has no resolved config yet (a test) relies on
---@return Lib.Keymap.Registered[]
function M.bind_preset(cfg)
  local api = require("emojis")

  ---@type Lib.Keymap.Spec
  local spec = {
    -- Only the `<leader>e*` keys form a group; `<C-e>` stands alone and needs
    -- no label beyond its own desc.
    prefix = "<leader>e",
    which_key = { group = "Emojis", mode = { "n", "x" } },
    order = { "insert", "overlay", "toggle", "count", "list" },
    actions = {
      insert = {
        default = "<C-e>",
        mode = { "n", "i" },
        rhs = api.insert,
        desc = "insert picker",
      },

      overlay = {
        default = "<leader>ee",
        rhs = function()
          api.overlay()
        end,
        desc = "quick-insert overlay",
      },

      -- Also in visual mode: the checkbox actions are range-aware, so this
      -- over a selection ticks a whole block.
      toggle = {
        default = "<leader>et",
        mode = { "n", "x" },
        rhs = function()
          api.toggle()
        end,
        desc = "toggle checkbox",
      },

      count = { default = "<leader>ec", rhs = api.count, desc = "count buffer" },

      list = {
        default = "<leader>el",
        rhs = function()
          local scope_m = require("emojis.core.scope")
          local target = scope_m.resolve("%", 0, 0, 0)
          if target then
            require("emojis.actions").list(target)
          end
        end,
        desc = "list buffer",
      },
    },
  }

  return keymap.register("emojis", spec, cfg and cfg.keymaps)
end

return M
