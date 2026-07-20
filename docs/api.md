# Lua API

```lua
local emojis = require("emojis")

emojis.setup(opts)   -- configure + activate (idempotent)
emojis.clear()       -- clean the whole buffer
emojis.count()       -- count emojis in the buffer
emojis.insert()      -- open the insert picker
emojis.overlay(mode) -- open the quick-insert overlay ("grid"|"grid_keys"|"list", optional)

emojis.toggle(set, dir)  -- cycle the checkbox on the cursor line / visual range
emojis.checkbox_add(set)    -- add a checkbox to the cursor line / visual range if it lacks one
emojis.checkbox_remove(set) -- remove the checkbox from the cursor line / visual range
emojis.cascade_groups(set)  -- config.checkbox.sets in cascade.nvim's cycle.groups format

emojis.ops()         -- pure clear/count/list/replace functions (for scripts/tests)
```

The pure operations work on string arrays and don't touch the Neovim API:

```lua
local ops = require("emojis").ops()
local cleaned, removed = ops.clear({ " 🚀 done" })   -- { " done" }, 1
local n                = ops.count({ "a ⚠️ b" })      -- 1
```

The overlay's usage history is also reachable, e.g. to clear it:

```lua
require("emojis.overlay.frecency").reset()
```
