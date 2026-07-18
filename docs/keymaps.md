# Recommended Keymaps

Enable via `require("emojis").setup({ keymaps = { preset = true } })`
(default: `false`). This automatically labels the `<leader>e` group in
which-key, if installed (`lua/emojis/bindings/which_key.lua`, optional
dependency). Full overview: [`docs/BINDINGS.md`](BINDINGS.md).

| Key | Mode | Action |
|---|---|---|
| `<C-e>` | n, i | Insert picker at the cursor |
| `<leader>ec` | n | Count emojis in the buffer |
| `<leader>el` | n | Emojis in the buffer -> quickfix |

Alternatively, set your own keymaps on `:Emojis`:

```lua
vim.keymap.set({ "n", "i" }, "<C-e>", "<cmd>Emojis insert<cr>", { desc = "Emoji: Picker" })
vim.keymap.set("n", "<leader>ec", "<cmd>Emojis count %<cr>",    { desc = "Emoji: Count" })
vim.keymap.set("n", "<leader>el", "<cmd>Emojis list %<cr>",     { desc = "Emoji: List" })
```
