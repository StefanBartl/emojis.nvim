---@module 'emojis.search'
---@brief Async project-wide emoji search (cwd scope) via ripgrep.
---@description
--- Uses `vim.system` when available and falls back to `jobstart`. Results feed
--- either a notify count or the quickfix list. The ripgrep Unicode codepoint
--- range mirrors the byte patterns used by `core.patterns`.

local fn = vim.fn

local notify = require("emojis.util.notify")
local config = require("emojis.config")

local M = {}

-- rg Unicode codepoint range — works without --pcre2.
local RG_PATTERN = [=[[\x{1F000}-\x{1FFFF}\x{2600}-\x{27FF}\x{2B00}-\x{2BFF}]]=]

---Turn collected `file:line:text` lines into the count/quickfix result.
---@param action "list"|"count"
---@param lines string[]
---@param cwd string
---@return nil
local function finish(action, lines, cwd)
  if #lines == 0 then
    notify.info("no emojis found under cwd")
    return
  end

  if action == "count" then
    notify.info(("Found %d match%s under %s"):format(
      #lines, #lines == 1 and "" or "es", fn.fnamemodify(cwd, ":~")))
    return
  end

  local qf = {}
  for i = 1, #lines do
    local raw = lines[i]
    local file, lnum = raw:match("^(.+):(%d+):")
    if file and lnum then
      qf[#qf + 1] = {
        filename = file,
        lnum = tonumber(lnum),
        col = 1,
        text = raw:match("^.+:%d+:(.*)$") or "",
      }
    end
  end
  if #qf == 0 then
    notify.warn("search output could not be parsed")
    return
  end
  fn.setqflist({}, "r", { title = "Emojis (cwd)", items = qf })
  vim.cmd("copen")
  notify.info(("Found %d match%s -> quickfix"):format(#qf, #qf == 1 and "" or "es"))
end

---Run the async cwd search for `list` or `count`.
---@param action "list"|"count"
---@return nil
function M.run(action)
  if action ~= "list" and action ~= "count" then
    notify.warn("cwd scope only supports list/count")
    return
  end

  local cfg = config.get().search
  if fn.executable(cfg.cmd) ~= 1 then
    notify.error(("'%s' not found on PATH; cwd scope needs ripgrep"):format(cfg.cmd))
    return
  end

  local cwd = fn.getcwd()
  notify.info("Searching cwd for emojis (async)...")

  local cmd = { cfg.cmd }
  for i = 1, #cfg.extra_args do
    cmd[#cmd + 1] = cfg.extra_args[i]
  end
  cmd[#cmd + 1] = RG_PATTERN
  cmd[#cmd + 1] = cwd

  local out, err_buf = {}, {}

  local function on_done(code)
    -- rg exits 1 when there are simply no matches.
    if code ~= 0 and code ~= 1 then
      notify.warn(("%s exited %d: %s"):format(cfg.cmd, code, table.concat(err_buf, "")))
      return
    end
    finish(action, out, cwd)
  end

  if type(vim.system) == "function" then
    vim.system(cmd, {
      text = true,
      stdout = function(_, d)
        if not d or d == "" then return end
        for _, l in ipairs(vim.split(d, "\n", { plain = true })) do
          if l ~= "" then out[#out + 1] = l end
        end
      end,
      stderr = function(_, d)
        if d and d ~= "" then err_buf[#err_buf + 1] = d end
      end,
    }, vim.schedule_wrap(function(o) on_done(o.code) end))
  else
    fn.jobstart(cmd, {
      on_stdout = function(_, d)
        for _, l in ipairs(d or {}) do if l ~= "" then out[#out + 1] = l end end
      end,
      on_stderr = function(_, d)
        for _, l in ipairs(d or {}) do if l ~= "" then err_buf[#err_buf + 1] = l end end
      end,
      on_exit = vim.schedule_wrap(function(_, c) on_done(c) end),
    })
  end
end

return M
