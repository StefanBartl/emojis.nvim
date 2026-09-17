-- TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by TESTS/run.lua.

local H = {}

--- Number of assertions executed so far. The runner reads and resets it per
--- spec, so a spec that loops over a table reports the checks it actually ran
--- rather than the assertion call sites it was written with.
---@type integer
H.checks = 0

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  H.checks = H.checks + 1
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  H.checks = H.checks + 1
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Run `fn` with `emojis.util.notify` recording instead of notifying, and
--- return what it said.
---
--- Every user-visible message of this plugin goes through that one module, so
--- capturing it is how a spec asserts on the *message* a branch produces
--- rather than only on the buffer it did or did not touch. The three fields are
--- replaced in place (the module table is the same object every caller holds a
--- reference to) and restored even when `fn` raises.
---
--- `fn` receives the record as it fills, which is what an asynchronous case
--- needs: it can wait for the message it expects (`vim.wait`) from inside the
--- capture, instead of returning before the scheduled callback ever ran.
---@param fn fun(said: {info: string[], warn: string[], error: string[]}): nil
---@return {info: string[], warn: string[], error: string[]}
function H.notices(fn)
  local notify = require("emojis.util.notify")
  local said = { info = {}, warn = {}, error = {} }
  local real = { info = notify.info, warn = notify.warn, error = notify.error }

  for _, level in ipairs({ "info", "warn", "error" }) do
    notify[level] = function(msg)
      said[level][#said[level] + 1] = tostring(msg)
    end
  end

  local ok, err = pcall(fn, said)

  notify.info, notify.warn, notify.error = real.info, real.warn, real.error
  if not ok then
    error(err, 0)
  end
  return said
end

--- Fresh scratch buffer, made current, with an optional filetype.
---@param ft string|nil
---@return integer bufnr
function H.scratch(ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

return H
