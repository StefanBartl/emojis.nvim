# Installation

See [requirements.md](requirements.md) for the full prerequisites table
(Neovim version, required and optional plugins, `ripgrep`).

## lazy.nvim

```lua
{
  "WKDSteve/emojis.nvim",
  dependencies = { "WKDSteve/lib.nvim" }, -- required
  cmd = "Emojis",
  opts = {},
}
```

## packer.nvim

```lua
use {
  "WKDSteve/emojis.nvim",
  requires = { "WKDSteve/lib.nvim" }, -- required
  config = function()
    require("emojis").setup()
  end,
}
```

## vim-plug

```vim
Plug 'WKDSteve/lib.nvim' " required
Plug 'WKDSteve/emojis.nvim'

lua require("emojis").setup()
```

## Verifying the installation

```
:checkhealth emojis
```
