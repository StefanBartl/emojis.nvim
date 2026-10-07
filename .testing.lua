-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "emojis",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "file",
  -- Guards (safety nets, see testing.nvim docs/GUARDS.md). The suite writes no files outside the
  -- temp dir, starts no processes, opens no connections and answers no prompts, so those are errors.
  guards = {
    fs = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
    -- Warn only, real findings: the specs leave scratch buffers ([No Name]), buffer-local keymaps,
    -- highlight groups and some autocmds / user commands behind (plus plugin setup() state);
    -- isolated = "file" keeps that from reaching the next spec file.
    state = "warn",
  },
  -- Nothing to allow: the suite neither writes files outside the temp dir, starts processes nor
  -- opens connections.
  guard_allow = { fs = {}, spawn = {}, network = {} },
}
