> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

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

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/emojis.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/emojis.nvim/actions/workflows/ci.yml)

One `:Emojis` command that removes, counts, lists, replaces, wraps and inserts
emojis — across a line, a selection, a buffer, or a whole project.

Emoji detection runs on a pure UTF-8 byte tokenizer. No external library, no
grammar, and the same result on every platform.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Installation](docs/installation.md) — prerequisites, every plugin manager, and verifying the install.
- [Configuration](docs/configuration.md) — every option and its default.
- [Commands](docs/commands.md) — actions, scopes, the double-space fix, project-wide `cwd` search, and usage examples.
- [Keymaps](docs/keymaps.md) — the recommended opt-in preset.
- [Lua API](docs/api.md) — the public API and the pure operations, for scripts and tests.
- [Architecture](docs/architecture.md) — module layout and design notes.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, command and autocommand at a glance.
- [Features](docs/FEATURES.md) — one section per feature, and why each has the shape it has.
- [Workflow](docs/WORKFLOW.md) — how the commands combine day to day, rather than what each one does.
- [Test suite](TESTS/README.md) — the headless, purely functional suite.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add an action.

`:help emojis` is the same reference inside the editor.

---

## What it does

Emoji handling is a family of small jobs that share exactly one hard part:
knowing where an emoji begins and ends. A skin-tone modifier, a zero-width
joiner, a variation selector and a regional-indicator pair are all several
codepoints that must be treated as one character — and every naive
`gsub`-with-a-pattern approach gets one of those wrong.

emojis.nvim solves that once, in a UTF-8 byte tokenizer with no dependencies,
and then puts the same tokenizer behind every action:

- **Removing and cleaning** — `clear` strips them, and fixes the double space
  left behind.
- **Counting and listing** — `count` reports, `list` collects them into the
  quickfix list.
- **Round-tripping** — `replace` turns emojis into `:name:` placeholders,
  `unreplace` turns them back, so a file can pass through a toolchain that
  mangles them and come out intact.
- **Wrapping** — surround them with a marker instead of removing them.
- **Inserting** — a searchable picker, or a quick-insert overlay of your
  most-used glyphs.
- **Navigating** — `first` and `next` jump the cursor to an emoji.
- **Checkboxes** — cycle `🔲` → `✅` on a line or a range.

Every action takes a scope: the current line, the Visual selection, the whole
buffer, or `cwd` for a project-wide pass through ripgrep — where the destructive
actions ask before they touch anything.

---

## Around it

> **[cascade.nvim](https://github.com/StefanBartl/cascade.nvim)** — a direct
> bridge rather than a coincidence: `require("emojis").cascade_groups()` feeds
> the configured checkbox glyphs into cascade's cursor-precise `<C-y>` cycling,
> so `:Emojis toggle` (line-scoped) and cascade's cycle (cursor-scoped) drive one
> shared vocabulary.
>
> **[markdown.nvim](https://github.com/StefanBartl/markdown.nvim)** — the
> documents where emoji checkboxes and `:name:` round-tripping actually matter.
>
> Both are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — `:Emojis` is registered through `lib.nvim.bindings.usercmd.composer` |

Optional, detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `ripgrep` | The project-wide `cwd` scope. Every other scope works without it |
| [cascade.nvim](https://github.com/StefanBartl/cascade.nvim) | Cursor-precise checkbox cycling over the same glyph sets |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/emojis.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- required
  cmd = "Emojis",
  opts = {},
}
```

`cmd = "Emojis"` is safe: nothing happens until you ask for it, and no keymaps
are bound unless you opt into the preset. Other plugin managers are in
[docs/installation.md](docs/installation.md).

---

## Quickstart

Clean the buffer you are in — that is the bare command's default action:

```vim
:Emojis
```

Then narrow the scope, or ask for a different action:

```vim
:Emojis clear line       " only the current line
:Emojis replace %        " emojis -> :name: in the whole buffer
:Emojis list %           " collect every emoji into the quickfix list
:Emojis insert           " searchable picker at the cursor
:Emojis overlay          " quick-insert float of your most-used glyphs
```

Verify your setup any time with:

```vim
:checkhealth emojis
```

---

## What you get with the defaults

Actions on the left, scopes as the argument: `line`, a Visual range, `%` for the
buffer, `cwd` for the project.

| Command | Does |
| --- | --- |
| `:Emojis clear [scope]` | Remove emojis, and fix the double space left behind — the default action |
| `:Emojis count [scope]` | Count them |
| `:Emojis list [scope]` | Collect them into the quickfix list |
| `:Emojis replace [scope]` | Emojis → `:name:` placeholders |
| `:Emojis unreplace [scope]` | `:name:` / `:U+XXXX:` placeholders → emojis |
| `:Emojis wrap [scope]` | Surround them with the configured marker, without removing them |
| `:Emojis insert` | The searchable insert picker, at the cursor |
| `:Emojis overlay [grid\|grid_keys\|list]` | Quick-insert float of your most-used emojis |
| `:Emojis toggle [set]` | Cycle an emoji checkbox on the line or range |
| `:Emojis first` / `:Emojis next` | Jump the cursor to the first / next emoji |
| `:Emojis clear\|replace\|list\|count cwd` | Project-wide via ripgrep; the destructive ones confirm first |

`require("emojis").cascade_groups()` feeds the configured checkbox sets into
[cascade.nvim](https://github.com/StefanBartl/cascade.nvim) — see
[configuration.md](docs/configuration.md#cascadenvim-bridge). The full surface is
[docs/commands.md](docs/commands.md).

---

## Health check

```vim
:checkhealth emojis
```

Reports whether `lib.nvim` resolved, whether `ripgrep` is reachable for the `cwd`
scope, and whether the configured checkbox sets and markers are valid.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout; [docs/architecture.md](docs/architecture.md) explains the split between
the pure operations and the buffer layer that a new action has to respect.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/emojis.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/emojis.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
