# Architecture

```
plugin/emojis.lua          Load guard
lua/emojis/
  init.lua                 Public API, setup()
  @types.lua                LuaLS type definitions
  config/
    DEFAULTS.lua             Immutable default configuration
    init.lua                 Merge + access to the active config
  util/
    notify.lua               Prefixed notify wrapper (via util/lib.lua)
    lib.lua                   Soft bridge to lib.nvim (notify/map), with fallback
  core/
    patterns.lua              Pure UTF-8 emoji tokenizer (graphemes incl. VS16)
    ops.lua                    Pure clear/count/list/replace operations
    scope.lua                  Scope (+ range) -> buffer line range
  bindings/
    init.lua                  Orchestrates usrcmds/keymaps/autocmds
    usrcmds.lua                Registers :Emojis (via commands.lua)
    keymaps.lua                 Opt-in preset keymaps (keymaps.preset)
    which_key.lua                Optional which-key group label
    autocmds.lua                  Empty (deliberately no autocmds, see ROADMAP)
  actions.lua                  Buffer-touching handlers (edit/list/count)
  nav.lua                      Cursor navigation (first/next)
  picker.lua                   Insert picker (vim.ui.select)
  search.lua                   Asynchronous cwd search (ripgrep)
  commands.lua                 :Emojis dispatch + tab completion
  health.lua                   :checkhealth emojis
```

Cheatsheet of all keymaps/commands/autocmds: [`docs/BINDINGS.md`](BINDINGS.md).
Test suite (purely functional, headless): [`docs/TESTS/README.md`](TESTS/README.md).

Pure logic (`core/*`) is separated from all API/UI layers and is therefore
independently testable.
