# Installation

See [requirements.md](requirements.md) for the full prerequisites table
(Neovim version, required and optional plugins, `ripgrep`).

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
