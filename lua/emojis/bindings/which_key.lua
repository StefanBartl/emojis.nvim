---@module 'emojis.bindings.which_key'
---@brief Optional, guarded which-key group label for the `<leader>e` prefix.
---@description
--- which-key is a **soft** dependency: if it is not installed this is a no-op.
--- Only the preset's `<leader>e*` keys need a group label; `<C-e>` already
--- carries its own `desc`. Supports both which-key v3 (`add`) and v2
--- (`register`) APIs.

local M = {}

---Register the `<leader>e` group with which-key, if available.
---@return boolean registered
function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end
  if type(wk.add) == "function" then
    wk.add({ { "<leader>e", group = "Emojis", mode = { "n" } } })
    return true
  elseif type(wk.register) == "function" then
    wk.register({ ["<leader>e"] = { name = "+Emojis" } }, { mode = "n" })
    return true
  end
  return false
end

---Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M
