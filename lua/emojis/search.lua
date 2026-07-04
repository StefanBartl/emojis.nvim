---@module 'emojis.search'
---@brief Async project-wide emoji search (cwd scope) via ripgrep.
---@description
--- Uses `vim.system` when available and falls back to `jobstart`. `list`/
--- `count` feed the quickfix list / a notify count. `clear`/`replace` first
--- collect the same matches, then ask for confirmation (`:Emojis list cwd`
--- is the dry-run preview for these) before mutating every matched file.
--- Buffers with unsaved changes are skipped rather than clobbered. The
--- ripgrep Unicode codepoint range mirrors the byte patterns used by
--- `core.patterns`.

local api = vim.api
local fn = vim.fn

local notify = require("emojis.util.notify")
local config = require("emojis.config")
local ops = require("emojis.core.ops")

local M = {}

-- rg Unicode codepoint range — works without --pcre2.
local RG_PATTERN = [=[[\x{1F000}-\x{1FFFF}\x{2600}-\x{27FF}\x{2B00}-\x{2BFF}]]=]

---@type table<string, boolean>  Actions the cwd scope supports.
local SUPPORTED = { list = true, count = true, clear = true, replace = true }

---Distinct file paths in `file:line:text` order of first appearance.
---@param lines string[]
---@return string[]
local function files_of(lines)
  local files, seen = {}, {}
  for i = 1, #lines do
    local file = lines[i]:match("^(.+):%d+:")
    if file and not seen[file] then
      seen[file] = true
      files[#files + 1] = file
    end
  end
  return files
end

---Apply `clear`/`replace` to every matched file, after confirmation.
---@param action "clear"|"replace"
---@param match_lines string[]  raw rg `file:line:text` output
---@param confirm_fn fun(msg: string, choices: string, default: integer): integer
---@return nil
function M.apply_across_files(action, match_lines, confirm_fn)
  local files = files_of(match_lines)
  if #files == 0 then
    notify.warn("search output could not be parsed")
    return
  end

  local verb = (action == "clear") and "Clear" or "Replace"
  local choice = confirm_fn(("%s emojis across %d file(s)? (see :Emojis list cwd first)"):format(verb, #files), "&Yes\n&No", 2)
  if choice ~= 1 then
    notify.info("cancelled")
    return
  end

  local names = config.get().names
  local total_n, total_files, skipped = 0, 0, 0

  for i = 1, #files do
    local path = files[i]
    local bufnr = fn.bufnr(path)
    local loaded = bufnr ~= -1 and api.nvim_buf_is_loaded(bufnr)

    if loaded and vim.bo[bufnr].modified then
      skipped = skipped + 1
    else
      local lines = loaded and api.nvim_buf_get_lines(bufnr, 0, -1, false) or fn.readfile(path)

      local new_lines, n
      if action == "clear" then
        new_lines, n = ops.clear(lines)
      else
        new_lines, n = ops.replace(lines, names)
      end

      if n > 0 then
        if loaded then
          api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
          api.nvim_buf_call(bufnr, function()
            vim.cmd("silent write")
          end)
        else
          fn.writefile(new_lines, path)
        end
        total_n = total_n + n
        total_files = total_files + 1
      end
    end
  end

  local verb_done = (action == "clear") and "Removed" or "Replaced"
  local msg = ("%s %d emoji%s across %d file%s"):format(
    verb_done,
    total_n,
    total_n == 1 and "" or "s",
    total_files,
    total_files == 1 and "" or "s"
  )
  if skipped > 0 then
    msg = msg .. (" (%d skipped: unsaved buffer)"):format(skipped)
  end
  notify.info(msg)
end

---Turn collected `file:line:text` lines into the requested result.
---@param action "list"|"count"|"clear"|"replace"
---@param lines string[]
---@param cwd string
---@return nil
local function finish(action, lines, cwd)
  if #lines == 0 then
    notify.info("no emojis found under cwd")
    return
  end

  if action == "count" then
    notify.info(("Found %d match%s under %s"):format(#lines, #lines == 1 and "" or "es", fn.fnamemodify(cwd, ":~")))
    return
  end

  if action == "clear" or action == "replace" then
    M.apply_across_files(action, lines, fn.confirm)
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

---Run the async cwd search for `list`, `count`, `clear`, or `replace`.
---@param action "list"|"count"|"clear"|"replace"
---@return nil
function M.run(action)
  if not SUPPORTED[action] then
    notify.warn("cwd scope only supports list/count/clear/replace")
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
    vim.system(
      cmd,
      {
        text = true,
        stdout = function(_, d)
          if not d or d == "" then
            return
          end
          for _, l in ipairs(vim.split(d, "\n", { plain = true })) do
            if l ~= "" then
              out[#out + 1] = l
            end
          end
        end,
        stderr = function(_, d)
          if d and d ~= "" then
            err_buf[#err_buf + 1] = d
          end
        end,
      },
      vim.schedule_wrap(function(o)
        on_done(o.code)
      end)
    )
  else
    fn.jobstart(cmd, {
      on_stdout = function(_, d)
        for _, l in ipairs(d or {}) do
          if l ~= "" then
            out[#out + 1] = l
          end
        end
      end,
      on_stderr = function(_, d)
        for _, l in ipairs(d or {}) do
          if l ~= "" then
            err_buf[#err_buf + 1] = l
          end
        end
      end,
      on_exit = vim.schedule_wrap(function(_, c)
        on_done(c)
      end),
    })
  end
end

return M
