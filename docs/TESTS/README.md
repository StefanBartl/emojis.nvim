# Tests

Headless spec suite for emojis.nvim. The tokenizer/ops/scope layers are pure
functions on strings — trivially testable without a UI.

`commands_spec.lua` calls `emojis.setup()`, which registers `:Emojis` via
`lib.nvim.usercmd.composer` — a real runtime dependency as of that migration,
not an optional extra. Check out `lib.nvim` as a sibling of this repo (same
convention as every other `StefanBartl/*.nvim` repo's test suite) and add it
to the runtimepath.

## Run

From the repo root, with `../lib.nvim` checked out as a sibling:

```sh
nvim --headless -u NONE -c "set rtp+=.,../lib.nvim" -c "luafile docs/TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero on the first failure
(`EMOJIS_TESTS_OK` on success).

## Layout

| File                | Covers                                                         |
| ------------------- | --------------------------------------------------------------- |
| `harness.lua`       | Shared assertions (`eq`, `ok`) and a `scratch(ft)` buffer helper. |
| `patterns_spec.lua` | Tokenizer: base emoji matching, VS16 grapheme handling, spans.   |
| `ops_spec.lua`      | `clear`/`replace`/`unreplace`/`wrap`/`count`/`list` on string arrays, space-collapse. |
| `scope_spec.lua`    | Scope resolution: `%`, `line`, `word`, `visual`, range override, `cwd`. |
| `config_spec.lua`   | DEFAULTS catalog: `picks`/`names` stay in sync, no codepoint collisions. |
| `commands_spec.lua` | `:Emojis` actions/scopes; `keymaps.preset` gates the preset keys.  |
| `search_spec.lua`   | `build_cmd()` glob/no_ignore flags; `apply_across_files()` confirm-gated cwd clear/replace. |
| `picker_spec.lua`   | Insert picker: engine selection falls back to `vim.ui.select`.    |
| `run.lua`           | Runner: loads every `*_spec.lua`, reports results, sets exit code. |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.scratch`) and add its filename to the `specs` list in `run.lua`.
