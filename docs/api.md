# Lua API

```lua
local emojis = require("emojis")

emojis.setup(opts)   -- configure + activate (idempotent)
emojis.clear()       -- clean the whole buffer
emojis.count()       -- count emojis in the buffer
emojis.insert()      -- open the insert picker
emojis.ops()         -- pure clear/count/list/replace functions (for scripts/tests)
```

The pure operations work on string arrays and don't touch the Neovim API:

```lua
local ops = require("emojis").ops()
local cleaned, removed = ops.clear({ " 🚀 done" })   -- { " done" }, 1
local n                = ops.count({ "a ⚠️ b" })      -- 1
```
