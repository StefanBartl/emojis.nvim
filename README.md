> **Active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# emojis.nvim

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
**replace**/**unreplace**, or **wrap** emojis — across different scopes
(current line, visual selection, whole buffer, or project-wide via ripgrep).
It also **inserts** emojis, either via a searchable picker or a quick-insert
**overlay** of your most-used glyphs, jumps the cursor to the **first**/**next**
emoji in the buffer, and cycles emoji **checkboxes** (`🔲` → `✅`) on a line or
range.

Cross-platform; emoji detection runs on a pure UTF-8 byte tokenizer (no
external library). Requires [`lib.nvim`](https://github.com/StefanBartl/lib.nvim)
— the `:Emojis` command is registered via `lib.nvim.bindings.usercmd.composer`.

---

## Table of Contents

- [Capabilities](#capabilities)
- [Quickstart](#quickstart)
- [Documentation](#documentation)

---

## Capabilities

| Command | Description | Docs |
|---|---|---|
| `:Emojis clear [scope]` | Remove emojis from the scope (default action) | [Commands](docs/commands.md) |
| `:Emojis count [scope]` | Count emojis in the scope | [Commands](docs/commands.md) |
| `:Emojis list [scope]` | Collect emojis into the quickfix list | [Commands](docs/commands.md) |
| `:Emojis replace [scope]` | Replace emojis with `:name:` placeholders | [Commands](docs/commands.md) |
| `:Emojis unreplace [scope]` | Restore `:name:`/`:U+XXXX:` placeholders back to emojis | [Commands](docs/commands.md) |
| `:Emojis wrap [scope]` | Surround emojis with the configured marker, without removing them | [Commands](docs/commands.md) |
| `:Emojis insert` | Open the searchable insert picker at the cursor | [Commands](docs/commands.md) |
| `:Emojis overlay [grid\|grid_keys\|list]` | Quick-insert float of your most-used emojis | [Commands](docs/commands.md#quick-insert-overlay) |
| `:Emojis toggle [set]` | Cycle an emoji checkbox on the cursor line / range | [Commands](docs/commands.md#emoji-checkboxes) |
| `:Emojis first` / `:Emojis next` | Jump the cursor to the first / next emoji in the buffer | [Commands](docs/commands.md) |
| `:Emojis clear\|replace\|list\|count cwd` | Project-wide search via ripgrep; `clear`/`replace` ask for confirmation | [Commands](docs/commands.md#project-wide-clearreplace-cwd-scope) |
| `require("emojis").cascade_groups()` | Feed the configured checkbox sets into [cascade.nvim](https://github.com/StefanBartl/cascade.nvim)'s cursor-precise cycling | [Configuration](docs/configuration.md#cascadenvim-bridge) |

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
- [Test suite](TESTS/README.md) — headless, purely functional test suite.
