```
  ███████╗███╗   ███╗ ██████╗      ██╗██╗███████╗
  ██╔════╝████╗ ████║██╔═══██╗     ██║██║██╔════╝
  █████╗  ██╔████╔██║██║   ██║     ██║██║███████╗
  ██╔══╝  ██║╚██╔╝██║██║   ██║██   ██║██║╚════██║
  ███████╗██║ ╚═╝ ██║╚██████╔╝╚█████╔╝██║███████║
  ╚══════╝╚═╝     ╚═╝ ╚═════╝  ╚════╝ ╚═╝╚══════╝
                                            .nvim
```

[![CI](https://github.com/StefanBartl/emojis.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/emojis.nvim/actions/workflows/ci.yml)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)

> 💡 Pairs well with [cascade.nvim](https://github.com/StefanBartl/cascade.nvim):
> `require("emojis").cascade_groups()` feeds the same emoji checkbox glyphs
> into cascade's cursor-precise `<C-y>` cycling, so `:Emojis toggle` (line-scoped)
> and cascade's cycle (cursor-scoped) drive one shared vocabulary.

A universal `:Emojis` command for Neovim: **remove**, **count**, **list**,
**replace**, or **insert** emojis — across different scopes (current line,
visual selection, whole buffer, or project-wide via ripgrep).

Cross-platform; emoji detection runs on a pure UTF-8 byte tokenizer (no
external library). Requires [`lib.nvim`](https://github.com/StefanBartl/lib.nvim)
— the `:Emojis` command is registered via `lib.nvim.usercmd.composer`.

---

## Table of Contents

- [Quickstart](#quickstart)
- [Documentation](#documentation)

---

## Quickstart

```lua
-- lazy.nvim
{
  "StefanBartl/emojis.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- required
  cmd = "Emojis",
  opts = {},
}
```

```vim
:Emojis                  " clean the whole buffer (= clear %)
:Emojis clear line       " only the current line
:Emojis replace %        " emojis -> :name: in the whole buffer
:Emojis insert           " emoji picker at the cursor
```

## Documentation

- [Installation](docs/installation.md) — prerequisites, lazy.nvim / packer.nvim / vim-plug setup, and verifying the install.
- [Configuration](docs/configuration.md) — all available options and defaults.
- [Commands](docs/commands.md) — actions, scopes, the double-space fix, project-wide `cwd` search, and usage examples.
- [Keymaps](docs/keymaps.md) — recommended opt-in preset keymaps.
- [Lua API](docs/api.md) — public API and pure operations for scripts/tests.
- [Architecture](docs/architecture.md) — module layout and design notes.
- [Bindings cheatsheet](docs/BINDINGS.md) — machine-readable overview of every keymap, command, and autocommand.
- [Roadmap](docs/ROADMAP.md) — implementation status and deliberately-not-planned items.
- [Test suite](docs/TESTS/README.md) — headless, purely functional test suite.
