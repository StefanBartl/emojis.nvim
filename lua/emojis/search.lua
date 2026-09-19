---@module 'emojis.search'
--- Async project-wide emoji search (cwd scope) via ripgrep.
---
--- Uses `vim.system` when available and falls back to `jobstart`. `list`/
--- `count` feed the quickfix list / a notify count. `clear`/`replace` first
--- collect the same matches, then ask for confirmation (`:Emojis list cwd`
--- is the dry-run preview for these) before mutating every matched file.
--- Buffers with unsaved changes are skipped rather than clobbered. The ripgrep
--- Unicode range (`RG_PATTERN`) is meant to track the byte patterns in
--- `core.patterns` — see the CDX note below, it currently lags by one range.

local api = vim.api
local fn = vim.fn

local notify = require("emojis.util.notify")
local config = require("emojis.config")
local ops = require("emojis.core.ops")
local lib = require("emojis.util.lib")
local list = require("lib.nvim.ui.list")
local line_stream = require("lib.nvim.system.lines")

local M = {}

-- rg Unicode codepoint range — works without --pcre2.
--- CDX: covers three of the four `core.patterns.RANGES` — the Misc Technical
--- block (U+2300-23FF: ⌚ ⏳ ⏰ …) is missing, so a `cwd`-scoped
--- list/count/clear/replace silently skips those glyphs even though every
--- buffer-scoped action matches them. Adding the range is a behaviour change.
local RG_PATTERN = [=[[\x{1F000}-\x{1FFFF}\x{2600}-\x{27FF}\x{2B00}-\x{2BFF}]]=]

---@type table<string, boolean>  Actions the cwd scope supports.
local SUPPORTED = { list = true, count = true, clear = true, replace = true }

---Distinct file paths in `file:line:text` order of first appearance.
---@param lines string[]
---@return string[]
---@internal
local function files_of(lines)
  local files = {}
  for i = 1, #lines do
    -- Non-greedy up to the FIRST `:<digits>:`: a greedy `.+` would instead
    -- match up to the LAST one, folding any `:<digits>:`-shaped text in the
    -- matched line (a timestamp, a ratio, this plugin's own `:100:`
    -- shortcode) into the file name (PRIN-25).
    local file = lines[i]:match("^(.-):%d+:")
    if file then
      files[#files + 1] = file
    end
  end
  return lib.dedup_list(files)
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
  local total_n, total_files, skipped, failed = 0, 0, 0, 0

  for i = 1, #files do
    local path = files[i]
    local bufnr = fn.bufnr(path)
    local loaded = bufnr ~= -1 and api.nvim_buf_is_loaded(bufnr)

    if loaded and vim.bo[bufnr].modified then
      skipped = skipped + 1
    else
      -- ERR-01/ERR-42: this is a best-effort batch over independent files, so
      -- a file gone missing/unreadable between the scan and this write (or a
      -- read-only target) must not abort the whole run -- the files already
      -- rewritten and saved stay rewritten either way, and a raise here would
      -- only stop the rest of the batch from ever being attempted.
      local ok, err = pcall(function()
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
      end)
      if not ok then
        failed = failed + 1
        notify.warn(("%s: %s"):format(path, tostring(err)))
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
  if failed > 0 then
    msg = msg .. (" (%d failed, see above)"):format(failed)
  end
  notify.info(msg)
end

---Turn collected `file:line:text` lines into the requested result.
---@param action "list"|"count"|"clear"|"replace"
---@param lines string[]
---@param cwd string
---@return nil
---@internal
---@internal
---Append whole output lines to `sink`, dropping the blank ones.
---
---The splitting itself is `lib.nvim.system.lines`: neither transport hands
---over lines (a chunk can end mid-line, and `jobstart`'s list form continues
---the previous callback's last element -- `:h channel-lines`), and it strips
---the trailing CR that `vim.system`'s `text = true` does not, since that
---option never covered a function handler.
---
---Blank lines are dropped here rather than there. ripgrep does not emit any,
---and an empty entry would reach `files_of` as a match that parses into
---nothing -- but whether that is true is this caller's business, not the
---shared collector's.
---@param sink string[]
---@param candidates string[]
---@return nil
local function keep_lines(sink, candidates)
  for i = 1, #candidates do
    if candidates[i] ~= "" then
      sink[#sink + 1] = candidates[i]
    end
  end
end

---@internal
---Emit output that never got its newline, at EOF -- subject to the same
---blank-line filter as everything else.
---@param collector Lib.System.Lines.Collector
---@param sink string[]
---@return nil
local function flush_into(collector, sink)
  local last = collector.flush()
  if last and last ~= "" then
    sink[#sink + 1] = last
  end
end

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
    ---@diagnostic disable-next-line: param-type-mismatch
    M.apply_across_files(action, lines, fn.confirm)
    return
  end

  local qf = {}
  for i = 1, #lines do
    local raw = lines[i]
    -- Same non-greedy fix as files_of(), and captured in one pass so the
    -- text is whatever follows the SAME `:<digits>:` that split file/lnum,
    -- not independently re-matched against a different (greedy) split.
    local file, lnum, text = raw:match("^(.-):(%d+):(.*)$")
    if file and lnum then
      qf[#qf + 1] = {
        filename = file,
        lnum = tonumber(lnum),
        col = 1,
        text = text or "",
      }
    end
  end
  if #qf == 0 then
    notify.warn("search output could not be parsed")
    return
  end
  list.qf(qf, "Emojis (cwd)", { action = "r" })
  notify.info(("Found %d match%s -> quickfix"):format(#qf, #qf == 1 and "" or "es"))
end

---Build the rg command array for the cwd search.
---@param cfg Emojis.Config.Search
---@param extra_globs string[]|nil  e.g. `{ "*.md" }` from `:Emojis count cwd *.md`
---@param cwd string
---@return string[]
function M.build_cmd(cfg, extra_globs, cwd)
  local cmd = { cfg.cmd }
  for i = 1, #cfg.extra_args do
    cmd[#cmd + 1] = cfg.extra_args[i]
  end
  if cfg.no_ignore then
    cmd[#cmd + 1] = "--no-ignore"
  end
  if extra_globs then
    for i = 1, #extra_globs do
      cmd[#cmd + 1] = "--glob"
      cmd[#cmd + 1] = extra_globs[i]
    end
  end
  cmd[#cmd + 1] = RG_PATTERN
  cmd[#cmd + 1] = cwd
  return cmd
end

---Run the async cwd search for `list`, `count`, `clear`, or `replace`.
---@param action "list"|"count"|"clear"|"replace"
---@param extra_globs string[]|nil  extra `--glob` patterns (args after the scope keyword)
---@param no_ignore boolean|nil  force `--no-ignore` for this call only, without
---       changing `search.no_ignore`
---@return nil
function M.run(action, extra_globs, no_ignore)
  if not SUPPORTED[action] then
    notify.warn("cwd scope only supports list/count/clear/replace")
    return
  end

  local cfg = config.get().search
  if no_ignore then
    -- A shallow copy so the override lasts exactly this invocation: mutating
    -- the config would make one `:Emojis! clear cwd` silently change every
    -- later search in the session.
    cfg = vim.tbl_extend("force", {}, cfg, { no_ignore = true })
  end
  if fn.executable(cfg.cmd) ~= 1 then
    notify.error(("'%s' not found on PATH; cwd scope needs ripgrep"):format(cfg.cmd))
    return
  end

  local cwd = fn.getcwd()
  notify.info("Searching cwd for emojis (async)...")

  local cmd = M.build_cmd(cfg, extra_globs, cwd)

  local out, err_buf = {}, {}

  local function on_done(code)
    -- rg exits 1 when there are simply no matches.
    if code ~= 0 and code ~= 1 then
      notify.warn(("%s exited %d: %s"):format(cfg.cmd, code, table.concat(err_buf, "")))
      return
    end
    finish(action, out, cwd)
  end

  local collector = line_stream.collector()

  if type(vim.system) == "function" then
    vim.system(
      cmd,
      {
        -- `text = true` is deliberately absent: it only normalizes the stdout
        -- vim.system captures itself, never what a function handler is given,
        -- so it would read as a guarantee this path does not get. The
        -- collector does it instead.
        stdout = function(_, d)
          if d and d ~= "" then
            keep_lines(out, collector.feed(d))
          end
        end,
        stderr = function(_, d)
          if d and d ~= "" then
            err_buf[#err_buf + 1] = d
          end
        end,
      },
      vim.schedule_wrap(function(o)
        flush_into(collector, out)
        on_done(o.code)
      end)
    )
  else
    fn.jobstart(cmd, {
      -- `table.concat(d, "\n")` rebuilds exactly the bytes this callback was
      -- handed (@see :h channel-lines), so the collector sees one continuous
      -- stream and joins the partial line across callbacks itself.
      on_stdout = function(_, d)
        if d then
          keep_lines(out, collector.feed(table.concat(d, "\n")))
        end
      end,
      on_stderr = function(_, d)
        if d then
          err_buf[#err_buf + 1] = table.concat(d, "\n")
        end
      end,
      on_exit = vim.schedule_wrap(function(_, c)
        flush_into(collector, out)
        on_done(c)
      end),
    })
  end
end

return M
