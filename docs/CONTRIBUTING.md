# Contributing to emojis.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/emojis.nvim/issues); pull requests
very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it to
the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/emojis.nvim")
require("emojis").setup({})
```

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation.
- **One tokenizer, no patterns.** Emoji boundaries are decided in exactly one
  place, a pure UTF-8 byte tokenizer with no external library. A skin-tone
  modifier, a zero-width joiner, a variation selector and a regional-indicator
  pair are each several codepoints that must be treated as one character. Any
  `gsub` with a hand-written character class will get one of those wrong, and it
  will look correct in every test that happens not to include it.
- **Operations are pure; the buffer layer is separate.** An action takes lines
  and returns lines, so it can be tested headlessly and without a buffer. Only
  the thin layer above it reads or writes a buffer. That split is what makes the
  test suite purely functional, and it is the design constraint most worth
  keeping.
- **Destructive actions confirm at `cwd` scope.** `clear` and `replace` over a
  whole project ask first, and say how many files they are about to touch.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, never
  with a bare `nvim_create_user_command`.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/emojis/core/` | The UTF-8 tokenizer and the pure operations (clear, count, list, replace, wrap) |
| `lua/emojis/overlay/` | The quick-insert overlay and its grid/list renderings |
| `lua/emojis/bindings/` | The `:Emojis` route tree, scopes, and the opt-in keymap preset |
| `lua/emojis/config/` | Defaults, checkbox sets, markers, `setup()` validation |
| `lua/emojis/util/` | Shared helpers |
| `lua/emojis/health.lua` | `:checkhealth emojis` |
| `docs/` | Everything the README links to |
| `TESTS/` | The headless, purely functional suite |

## Adding an action

1. Implement it in `lua/emojis/core/` as a pure function over lines. It must not
   know what a buffer is.
2. Route it in `lua/emojis/bindings/` for every scope that makes sense, including
   `cwd` — and if it is destructive there, wire the confirmation.
3. Add a spec under `TESTS/`. Include at least one multi-codepoint emoji: a
   skin-tone modifier, a ZWJ sequence and a flag are the three cases that break
   naive implementations.
4. Document it in [`commands.md`](commands.md), [`FEATURES.md`](FEATURES.md) and
   [`BINDINGS.md`](BINDINGS.md).

## Tests

`TESTS/` runs headless and needs no buffer; [`TESTS/README.md`](../TESTS/README.md)
has the invocation. [GitHub Actions](../.github/workflows/ci.yml) runs it on
every push and PR to `main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.
