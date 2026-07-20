# Commands

## Overview

```
:Emojis [action] [scope]
:[range]Emojis [action]
```

Without arguments: `:Emojis` -> `:Emojis clear %` (removes all emojis in the buffer).

| Action | Description |
|---|---|
| `clear` | Removes all emojis in the scope (default) |
| `replace` | Replaces emojis with `:name:` placeholders |
| `unreplace` | Replaces `:name:`/`:U+XXXX:` placeholders back with emojis |
| `wrap` | Wraps emojis with the `config.wrap` marker, without removing them |
| `list` | Collects all emojis in the scope into the quickfix list |
| `count` | Counts the emojis in the scope and reports the result |
| `insert` | Opens a picker at the cursor for inserting an emoji |
| `first` | Jumps to the first emoji in the buffer (cursor navigation) |
| `next` | Jumps to the next emoji, wrapping to the top at the end of the buffer |

| Scope | Description |
|---|---|
| `%` | The entire current buffer (default) |
| `line` | The current cursor line |
| `word` | The contiguous, whitespace-free chunk of text under the cursor |
| `visual` | The last / current visual selection |
| `cwd` | Project-wide via ripgrep (async; `list`/`count`/`clear`/`replace`) |

An explicit Vim range (`:'<,'>Emojis`, `:10,20Emojis`) overrides the scope keyword.

Built via `lib.nvim.usercmd.composer`: one route per action, forwarding to
the same dispatch function as before this migration (`emojis.commands`'
`execute()`, unchanged). An unknown action now reports composer's own
"unknown subcommand" usage block instead of the plain `unknown action %q`
error string; `insert`/`first`/`next` still silently ignore a garbage
second argument, same as before.

## Fixed bug: double space

When removing emojis, the old version left two spaces behind:
`SPACE EMOJI SPACE` -> `SPACE SPACE`. `emojis.nvim` collapses the spaces on
both sides of a removed emoji (or emoji run) down to **one** space:

```
" 🚀 "        ->  " "
"a 🚀 b"      ->  "a b"
" 🚀🔥 "      ->  " "
```

In addition, VS16 emojis (e.g. ⚠️) are correctly treated as **one** emoji —
previously they were counted twice and turned into `:warning::U+FE0F:` by
`replace`.

Optional (`preview.enable = true`): before `clear`/`replace`, the affected
emojis are briefly highlighted (default 150 ms) with `preview.hl_group`
before the buffer is changed.

## Project-wide clear/replace (`cwd` scope)

`:Emojis clear cwd` / `:Emojis replace cwd` search the project asynchronously
via ripgrep and ask for confirmation **before** every change (default:
cancel). Recommended workflow:

```vim
:Emojis list cwd         " dry run: check first what would be affected
:Emojis clear cwd        " then apply (confirm the dialog)
```

Buffers that are already open with unsaved changes are skipped (not
overwritten) and counted as "skipped" in the summary.

Additional arguments after the `cwd` keyword are passed through to ripgrep
as extra `--glob` filters (e.g. `*.md` for Markdown files only).
`search.no_ignore = true` also searches gitignored files (`--no-ignore`).

## Usage examples

```vim
:Emojis                  " clean the whole buffer (= clear %)
:Emojis clear line       " only the current line
:'<,'>Emojis clear       " clean the marked block (range overrides scope)
:Emojis replace %        " emojis -> :name: in the whole buffer
:Emojis unreplace %      " :name: -> emojis in the whole buffer
:Emojis list %           " buffer's emojis into the quickfix list
:Emojis count cwd        " count project-wide (async, rg)
:Emojis count cwd *.md   " count only in Markdown files (extra rg --glob)
:Emojis list cwd         " project-wide into the quickfix list
:Emojis clear cwd        " remove project-wide (confirmation dialog)
:Emojis replace cwd      " project-wide -> :name: (confirmation dialog)
:Emojis insert           " emoji picker at the cursor
:Emojis first            " jump to the first emoji in the buffer
:Emojis next             " jump to the next emoji (wraps at the end)
:Emojis wrap %           " wrap emojis with [[ ]] (marker configurable)
```
