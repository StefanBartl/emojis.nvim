# emojis.nvim documentation

What is here, and which question each page answers. [The README](../README.md)
is the short version of all of it.

## Getting it running

| Page | Answers |
| --- | --- |
| [installation.md](installation.md) | What has to be there first, then a spec per plugin manager |
| [configuration.md](configuration.md) | Every option `setup()` takes, with the full defaults printed out |

## Using it

| Page | Answers |
| --- | --- |
| [commands.md](commands.md) | Every `:Emojis` subcommand and the scope each one accepts |
| [keymaps.md](keymaps.md) | The optional keymap preset — off by default — and what each key does |
| [BINDINGS.md](BINDINGS.md) | Every keymap, user command and autocommand this plugin defines, in one machine-readable overview |
| [WORKFLOW.md](WORKFLOW.md) | The different question: not what each command does, but how they combine day to day |

## Why it is the way it is

| Page | Answers |
| --- | --- |
| [FEATURES.md](FEATURES.md) | One section per feature: the single entry point, UTF-8 detection without a name table, the six scope actions and the preview before a destructive one, project-wide scope over ripgrep, the insert picker and the quick-insert overlay, frecency reordering, emoji checkboxes, and the cascade.nvim bridge |
| [api.md](api.md) | Every Lua function a config or another plugin can call |
| [architecture.md](architecture.md) | Which file does what, from the load guard down |
