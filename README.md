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
> dependency — see [Requirements](docs/requirements.md).

---

## Documentation

Start at [docs/README.md](docs/README.md) — what's where, and which question
each page answers.

**The Basics**

- [Requirements](docs/requirements.md) — Neovim version, required and optional plugins, `ripgrep`.
- [Installation](docs/installation.md) — every plugin manager, and verifying the install.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing.

**Configuration**

- [All options](docs/configuration.md) — every `setup()` option and its default.
- [Commands](docs/commands.md) — every action/scope combination, the double-space fix, and usage examples.
- [Keymaps](docs/keymaps.md) — the optional preset, off by default.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, command and autocommand at a glance.

**The Rest**

- [What it does](docs/FEATURES.md) — one section per feature, why it has the shape it has, and what `:checkhealth emojis` reports.
- [How it's used day to day](docs/WORKFLOW.md) — how the commands combine in practice, not just what each one does.
- [Lua API](docs/api.md) — the public API and the pure operations, for scripts and tests.
- [Architecture](docs/architecture.md) — module layout and design notes.
- [Test suite](TESTS/README.md) — the headless, purely functional suite.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add an action.
- [Feedback](https://github.com/StefanBartl/emojis.nvim/issues)

`:help emojis` is the same reference inside the editor.

---

## License

MIT — see [LICENSE](LICENSE).
