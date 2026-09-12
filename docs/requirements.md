# Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — `:Emojis` is registered through `lib.nvim.bindings.usercmd.composer`, with no fallback. (`notify`/`map` specifically stay soft internally — native fallback if `lib.nvim` were somehow missing at that call site — but the command layer itself hard-requires the composer module, so treat the dependency as required overall.) |

Optional, detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `ripgrep` (`rg`) | The project-wide `cwd` scope. Every other scope works without it |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) | A live-search picker for `:Emojis insert` (`picker.engine = "auto"`), otherwise falls back to `vim.ui.select` |
| [cascade.nvim](https://github.com/StefanBartl/cascade.nvim) | Cursor-precise checkbox cycling over the same glyph sets, via `require("emojis").cascade_groups()` |

Verify all of the above any time with `:checkhealth emojis` — see
[installation.md](installation.md) for plugin-manager setup.
