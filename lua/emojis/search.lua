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
    local file = lines[i]:match("^(.+):%d+:")
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
---@internal
---@internal
---Collect a subprocess's stdout into whole lines.
---
---Neither transport hands over lines. `vim.system`'s function handler passes
---whatever libuv read, so a chunk can end mid-line and the rest arrives in the
---next one; splitting each chunk on its own therefore cuts that line in two.
---`jobstart` has the same property in list form (@see :h channel-lines): the
---first element of a callback continues the last element of the previous one.
---Measured on 4000 lines of output: per-chunk splitting produced 4026 entries,
---26 of them malformed. Those entries reach `files_of`, which is what
---`:Emojis clear cwd` derives the list of files to rewrite from -- so a cut
---line does not just show up wrong, it can drop a file from a destructive
---operation.
---
---The trailing CR goes too. `vim.system`'s `text = true` does not cover a
---function handler (only the stdout it captures itself), and ripgrep reports a
---match from a CRLF file with the CR still on it.
---Exported for TESTS/search_spec.lua, the same way `build_cmd` is: the two
---transports below are awkward to drive from a spec, the collector is not.
---@internal
---@param sink string[]  Non-empty lines are appended here
---@return { feed: fun(data: string), flush: fun() }
function M.line_collector(sink)
  local buffered = ""

  ---@param line string
  local function emit(line)
    if line:sub(-1) == "\r" then
      line = line:sub(1, -2)
    end
    if line ~= "" then
      sink[#sink + 1] = line
    end
  end

  return {
    feed = function(data)
      buffered = buffered .. data
      local parts = vim.split(buffered, "\n", { plain = true })
      -- The last part is either a partial line or "" (the chunk ended on a
      -- newline). Either way it is not complete yet, so it stays buffered.
      buffered = table.remove(parts) or ""
      for i = 1, #parts do
        emit(parts[i])
      end
    end,
    flush = function()
      local last = buffered
      buffered = ""
      emit(last)
    end,
  }
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

  local collector = M.line_collector(out)

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
            collector.feed(d)
          end
        end,
        stderr = function(_, d)
          if d and d ~= "" then
            err_buf[#err_buf + 1] = d
          end
        end,
      },
      vim.schedule_wrap(function(o)
        collector.flush()
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
          collector.feed(table.concat(d, "\n"))
        end
      end,
      on_stderr = function(_, d)
        if d then
          err_buf[#err_buf + 1] = table.concat(d, "\n")
        end
      end,
      on_exit = vim.schedule_wrap(function(_, c)
        collector.flush()
        on_done(c)
      end),
    })
  end
end

return M
