# Installation

## Prerequisites

- Neovim 0.9+
- `ripgrep` (`rg`) — only needed for the `cwd` scope, and only optionally
- [`lib.nvim`](https://github.com/StefanBartl/lib.nvim) — optional; used for
  `notify`/`map` when installed, otherwise a native fallback is used (no
  hard dependency)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or
  [fzf-lua](https://github.com/ibhagwan/fzf-lua) — optional; provides a
  live-search picker for `:Emojis insert` (`picker.engine = "auto"`),
  otherwise falls back to `vim.ui.select`

## lazy.nvim

```lua
{
  "StefanBartl/emojis.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- optional: nicer notify/map if present
  cmd = "Emojis",
  opts = {},
}
```

## packer.nvim

```lua
use {
  "StefanBartl/emojis.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- optional
  config = function()
    require("emojis").setup()
  end,
}
```

## vim-plug

```vim
Plug 'StefanBartl/lib.nvim' " optional
Plug 'StefanBartl/emojis.nvim'

lua require("emojis").setup()
```

## Verifying the installation

```
:checkhealth emojis
```
