# Installation

## Prerequisites

- Neovim 0.9+
- `ripgrep` (`rg`) — only needed for the `cwd` scope, and only optionally
- [`lib.nvim`](https://github.com/StefanBartl/lib.nvim) — **required**; the
  `:Emojis` command is registered via `lib.nvim.usercmd.composer`, with no
  fallback. (`notify`/`map` specifically stay soft internally — native
  fallback if `lib.nvim` were somehow missing at that call site — but the
  command layer itself hard-requires the composer module, so treat the
  dependency as required overall.)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or
  [fzf-lua](https://github.com/ibhagwan/fzf-lua) — optional; provides a
  live-search picker for `:Emojis insert` (`picker.engine = "auto"`),
  otherwise falls back to `vim.ui.select`

## lazy.nvim

```lua
{
  "StefanBartl/emojis.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- required
  cmd = "Emojis",
  opts = {},
}
```

## packer.nvim

```lua
use {
  "StefanBartl/emojis.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- required
  config = function()
    require("emojis").setup()
  end,
}
```

## vim-plug

```vim
Plug 'StefanBartl/lib.nvim' " required
Plug 'StefanBartl/emojis.nvim'

lua require("emojis").setup()
```

## Verifying the installation

```
:checkhealth emojis
```
