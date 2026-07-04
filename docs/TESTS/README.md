# Tests

Headless spec suite for emojis.nvim. The tokenizer/ops/scope layers are pure
functions on strings — trivially testable without a UI.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero on the first failure
(`EMOJIS_TESTS_OK` on success).

## Layout

| File                | Covers                                                         |
| ------------------- | --------------------------------------------------------------- |
| `harness.lua`       | Shared assertions (`eq`, `ok`) and a `scratch(ft)` buffer helper. |
| `patterns_spec.lua` | Tokenizer: base emoji matching, VS16 grapheme handling, spans.   |
| `ops_spec.lua`      | `clear`/`count`/`list`/`replace` on string arrays, space-collapse. |
| `scope_spec.lua`    | Scope resolution: `%`, `line`, `visual`, range override, `cwd`.  |
| `commands_spec.lua` | `:Emojis` exists after setup; `keymaps.preset` gates the preset keys. |
| `run.lua`           | Runner: loads every `*_spec.lua`, reports results, sets exit code. |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.scratch`) and add its filename to the `specs` list in `run.lua`.
