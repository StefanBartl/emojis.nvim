-- TESTS/search_run_spec.lua — the async cwd search around ripgrep.
--
-- No subprocess is ever started: `vim.system` (and, for the fallback branch,
-- `vim.fn.jobstart`) is replaced with a double that plays back a recorded
-- stdout stream. That is what makes the interesting part testable at all --
-- neither transport hands over whole lines, so a chunk can end mid-line, and
-- the line collector has to rejoin it. Those chunk boundaries are scripted
-- here on purpose.
--
-- search_spec.lua covers `build_cmd` and the confirm-gated file mutation;
-- this one covers `run`/`finish`: the guards before the spawn, the collector,
-- and the four result shapes.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local search = require("emojis.search")
  local config = require("emojis.config")

  config.setup({})

  --- Run `fn` with a scripted rg: every string in `chunks` is handed to the
  --- stdout handler as one chunk, then the process exits with `code`.
  --- Returns the command array the plugin built.
  ---@param chunks string[]
  ---@param code integer
  ---@param fn fun(): nil
  ---@return string[] cmd
  local function with_rg(chunks, code, fn)
    local real_system, real_exec = vim.system, vim.fn.executable
    local cmd
    vim.fn.executable = function()
      return 1
    end
    vim.system = function(argv, opts, on_exit)
      cmd = argv
      for i = 1, #chunks do
        opts.stdout(nil, chunks[i])
      end
      opts.stderr(nil, "")
      on_exit({ code = code })
      return { wait = function() end }
    end

    local called_ok, err = pcall(fn)

    vim.system, vim.fn.executable = real_system, real_exec
    if not called_ok then
      error(err, 0)
    end
    return cmd
  end

  -- ----------------------------------------------------------------- guards
  do
    local said = H.notices(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      search.run("wrap", nil, nil)
    end)
    eq(said.warn[1], "cwd scope only supports list/count/clear/replace", "run: an unsupported action never spawns")
  end

  do
    config.setup({ search = { cmd = "emojis-nvim-no-such-tool" } })
    local said = H.notices(function()
      search.run("list", nil, nil)
    end)
    ok(said.error[1]:find("not found on PATH", 1, true) ~= nil, "run: a missing ripgrep is reported, not spawned")
    config.setup({})
  end

  -- The per-call `--no-ignore` override must not outlive the call.
  do
    local cmd = with_rg({}, 1, function()
      H.notices(function(said)
        search.run("list", nil, true)
        vim.wait(2000, function()
          return #said.info > 1
        end, 5)
      end)
    end)
    eq(vim.tbl_contains(cmd, "--no-ignore"), true, "run: the bang adds --no-ignore to this invocation")
    eq(config.get().search.no_ignore, false, "run: ... and leaves the configured value alone")
  end

  -- ------------------------------------------------------ the line collector
  -- Three chunks that split "a.txt:2:..." across a boundary, plus a CRLF
  -- line ending and a final line with no newline at all.
  do
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local a, b = dir .. "/a.txt", dir .. "/b.txt"

    local said = H.notices(function(record)
      with_rg(
        {
          a .. ":1:first 🚀 line\r\n" .. a .. ":2:sec",
          "ond ⭐ line\n" .. b .. ":7:third 🔥 line\n",
          b .. ":9:no trailing newline 💡",
        },
        0,
        function()
          search.run("list", nil, nil)
          vim.wait(2000, function()
            return #record.info > 1
          end, 5)
        end
      )
    end)
    vim.cmd("cclose")

    local qf = vim.fn.getqflist()
    eq(#qf, 4, "collector: a line split across two chunks is rejoined, not dropped")
    eq(qf[1].lnum, 1, "finish: the line number is parsed")
    eq(qf[1].text, "first 🚀 line", "finish: the CR of a CRLF ending is stripped")
    eq(qf[2].text, "second ⭐ line", "collector: the rejoined line carries its full text")
    eq(qf[4].lnum, 9, "collector: the unterminated last line is flushed at EOF")
    eq(said.info[#said.info], "Found 4 matches -> quickfix", "finish: reports the match count")
    eq(vim.fn.getqflist({ title = 0 }).title, "Emojis (cwd)", "finish: the quickfix list is titled")

    vim.fn.delete(dir, "rf")
  end

  -- ------------------------------------------------------------ result shapes
  do
    local said = H.notices(function(record)
      with_rg({}, 1, function() -- rg exits 1 when there is simply no match
        search.run("list", nil, nil)
        vim.wait(2000, function()
          return #record.info > 1
        end, 5)
      end)
    end)
    eq(said.info[#said.info], "no emojis found under cwd", "finish: an empty result is not an error")
  end

  do
    local said = H.notices(function(record)
      with_rg({ "x.txt:1:a 🚀\ny.txt:2:b 🔥\n" }, 0, function()
        search.run("count", nil, nil)
        vim.wait(2000, function()
          return #record.info > 1
        end, 5)
      end)
    end)
    ok(said.info[#said.info]:find("Found 2 matches under ", 1, true) ~= nil, "finish: count reports matches, not files")
  end

  -- `clear`/`replace` collect first and then hand the raw match lines to the
  -- confirm-gated file mutation (covered end to end in search_spec.lua).
  do
    local real = search.apply_across_files
    local seen
    ---@diagnostic disable-next-line: assign-type-mismatch
    search.apply_across_files = function(action, lines, confirm_fn)
      seen = { action = action, lines = lines, confirm = confirm_fn }
    end
    H.notices(function()
      with_rg({ "x.txt:1:a 🚀\n" }, 0, function()
        search.run("clear", nil, nil)
        vim.wait(2000, function()
          return seen ~= nil
        end, 5)
      end)
    end)
    search.apply_across_files = real

    eq(seen and seen.action, "clear", "finish: clear hands over to apply_across_files")
    eq(seen and seen.lines[1], "x.txt:1:a 🚀", "finish: ... with the raw match lines")
    eq(seen and type(seen.confirm), "function", "finish: ... and a confirmation function")
  end

  -- A non-zero, non-1 exit is a failure of the tool itself.
  do
    local real_system, real_exec = vim.system, vim.fn.executable
    vim.fn.executable = function()
      return 1
    end
    vim.system = function(_, opts, on_exit)
      opts.stderr(nil, "rg: broken regex")
      on_exit({ code = 2 })
      return { wait = function() end }
    end
    local said = H.notices(function(record)
      search.run("list", nil, nil)
      vim.wait(2000, function()
        return #record.warn > 0
      end, 5)
    end)
    vim.system, vim.fn.executable = real_system, real_exec
    ok(said.warn[1]:find("exited 2", 1, true) ~= nil, "run: a tool failure is reported with its exit code")
    ok(said.warn[1]:find("broken regex", 1, true) ~= nil, "run: ... and its stderr")
  end

  -- Output that parses into nothing is reported rather than shown as an empty
  -- quickfix list.
  do
    local said = H.notices(function(record)
      with_rg({ "this is not rg output\n" }, 0, function()
        search.run("list", nil, nil)
        vim.wait(2000, function()
          return #record.warn > 0
        end, 5)
      end)
    end)
    eq(said.warn[1], "search output could not be parsed", "finish: unparseable output is reported")
  end

  -- ------------------------------------------------- the jobstart fallback
  -- On a Neovim without `vim.system`, the same collector runs behind
  -- `jobstart`'s list form, whose chunks continue the previous callback's last
  -- element -- so the two are rejoined with "\n" before feeding the collector.
  do
    local real_system, real_exec, real_job = vim.system, vim.fn.executable, vim.fn.jobstart
    vim.fn.executable = function()
      return 1
    end
    ---@diagnostic disable-next-line: cast-local-type
    vim.system = nil
    vim.fn.jobstart = function(_, opts)
      -- No trailing "" on the first callback: that is how jobstart signals a
      -- chunk that ended mid-line (:h channel-lines).
      opts.on_stdout(0, { "p.txt:3:split 🚀 he" })
      opts.on_stdout(0, { "re", "q.txt:4:second 💡", "" })
      opts.on_exit(0, 0)
      return 1
    end

    local said = H.notices(function(record)
      search.run("list", nil, nil)
      vim.wait(2000, function()
        return #record.info > 1
      end, 5)
    end)
    vim.system, vim.fn.executable, vim.fn.jobstart = real_system, real_exec, real_job
    vim.cmd("cclose")

    local qf = vim.fn.getqflist()
    eq(#qf, 2, "jobstart fallback: both matches arrive")
    eq(qf[1].text, "split 🚀 here", "jobstart fallback: a line split across callbacks is rejoined")
    eq(said.info[#said.info], "Found 2 matches -> quickfix", "jobstart fallback: same reporting as vim.system")
  end

  -- ------------------------------------------------------------ pinned fix
  -- `file:line:text` is split non-greedily (`^(.-):%d+:`), on the FIRST
  -- `:<digits>:`, not the last. This plugin's own shortcode vocabulary
  -- contains one (`:100:` for 💯), so a line holding both an emoji and that
  -- token must still resolve to the real file/line rg reported, not to a
  -- name that swallows the shortcode (PRIN-25).
  do
    local said = H.notices(function(record)
      with_rg({ "notes.md:3:scored 💯 out of :100:\n" }, 0, function()
        search.run("list", nil, nil)
        vim.wait(2000, function()
          return #record.info > 1
        end, 5)
      end)
    end)
    vim.cmd("cclose")
    local qf = vim.fn.getqflist()
    eq(#qf, 1, "fix(parse): the match is accepted ...")
    eq(qf[1].lnum, 3, "fix(parse): ... with the real line number from rg, not the :100: shortcode")
    eq(vim.fn.bufname(qf[1].bufnr), "notes.md", "fix(parse): ... and the filename stops at the real separator")
    eq(said.info[#said.info], "Found 1 match -> quickfix", "fix(parse): reported normally")
  end

  -- BUG: the ripgrep pattern covers three of the four codepoint ranges the
  -- in-buffer tokenizer matches -- Misc Technical (U+2300-23FF: ⌚ ⏳ ⏰ …) is
  -- missing. `:Emojis count %` sees those glyphs, `:Emojis count cwd` never
  -- will. Documented as a CDX note in search.lua; pinned here so the day the
  -- range is added, this assertion says so.
  do
    local cmd = search.build_cmd({ cmd = "rg", extra_args = {}, no_ignore = false }, nil, "/proj")
    local pattern = cmd[#cmd - 1]
    eq(pattern:find("2600", 1, true) ~= nil, true, "rg pattern: Misc Symbols is covered")
    eq(pattern:find("2300", 1, true), nil, "BUG(rg pattern): the Misc Technical range is missing")
    eq(require("emojis.core.patterns").count("⌚"), 1, "BUG(rg pattern): ... though the tokenizer matches it")
  end

  config.setup({})
end
