# Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — `:Emojis` is registered through `lib.nvim.bindings.usercmd.composer`, with no fallback, and the opt-in preset's keymap registry (`bindings/keymaps.lua`) bare-requires `lib.nvim.bindings.keymap` directly for its which-key-aware API, also with no fallback. (`notify`/`map` in `util/lib.lua` specifically stay soft — native fallback if `lib.nvim` were somehow missing — but only for the plugin's own internal, primitive call sites such as the overlay's grid keys; treat the dependency as required overall.) |

Optional, detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `ripgrep` (`rg`) | The project-wide `cwd` scope. Every other scope works without it |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) | A live-search picker for `:Emojis insert` (`picker.engine = "auto"`), otherwise falls back to `vim.ui.select` |
| [cascade.nvim](https://github.com/StefanBartl/cascade.nvim) | Cursor-precise checkbox cycling over the same glyph sets, via `require("emojis").cascade_groups()` |
| [ui.nvim](https://github.com/StefanBartl/ui.nvim) | `ui.kit.select` backs the `:Emojis overlay` grid and, when available, gives the picker's `select` mode (and the `telescope`/`fzf-lua`/`auto` fallback chain) its themed UI — lazily required, so nothing loads it until one of those runs; without it the overlay warns instead of opening, and the picker falls back further to plain `vim.ui.select` |

Verify all of the above any time with `:checkhealth emojis` — see
[installation.md](installation.md) for plugin-manager setup.
