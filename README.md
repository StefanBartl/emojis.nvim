# emojis.nvim

Ein universeller `:Emojis`-Befehl für Neovim: Emojis **entfernen**, **zählen**,
**auflisten**, **ersetzen** oder **einfügen** — auf verschiedenen Scopes
(aktuelle Zeile, Visual-Auswahl, ganzer Buffer oder projektweit via ripgrep).

Eigenständiges Plugin ohne `lib.nvim`-Abhängigkeit, plattformübergreifend.
Die Emoji-Erkennung läuft über einen reinen UTF-8-Byte-Tokenizer (keine externe
Bibliothek).

---

## Funktionsüberblick

```
:Emojis [action] [scope]
:[range]Emojis [action]
```

Ohne Argumente: `:Emojis` → `:Emojis clear %` (entfernt alle Emojis im Buffer).

| Aktion | Beschreibung |
|---|---|
| `clear` | Entfernt alle Emojis im Scope (Standard) |
| `replace` | Ersetzt Emojis durch `:name:`-Platzhalter |
| `list` | Sammelt alle Emojis im Scope in die Quickfix-Liste |
| `count` | Zählt die Emojis im Scope und meldet das Ergebnis |
| `insert` | Öffnet einen Picker am Cursor zum Einfügen |

| Scope | Beschreibung |
|---|---|
| `%` | Gesamter aktueller Buffer (Standard) |
| `line` | Aktuelle Cursor-Zeile |
| `word` | Aktuelle Zeile (Wort unter dem Cursor) |
| `visual` | Letzte / aktuelle visuelle Auswahl |
| `cwd` | Projektweit via ripgrep (asynchron; nur `list`/`count`) |

Ein expliziter Vim-Range (`:'<,'>Emojis`, `:10,20Emojis`) überschreibt das
Scope-Schlüsselwort.

---

## Behobener Bug: doppeltes Leerzeichen

Beim Entfernen ließ die alte Version zwei Leerzeichen zurück:
`LEERZEICHEN EMOJI LEERZEICHEN` → `LEERZEICHEN LEERZEICHEN`. `emojis.nvim`
kollabiert beidseitige Leerzeichen eines entfernten Emojis (oder einer
Emoji-Folge) auf **ein** Leerzeichen:

```
" 🚀 "        ->  " "
"a 🚀 b"      ->  "a b"
" 🚀🔥 "      ->  " "
```

Zusätzlich werden VS16-Emojis (z. B. ⚠️) korrekt als **ein** Emoji behandelt —
sie wurden zuvor doppelt gezählt und in `replace` zu `:warning::U+FE0F:`.

---

## Voraussetzungen

- Neovim 0.9+
- `ripgrep` (`rg`) — nur für den `cwd`-Scope optional erforderlich

---

## Installation

```lua
-- lazy.nvim (lokaler Checkout)
{
  dir = vim.env.REPOS_DIR .. "/emojis.nvim",
  cmd = "Emojis",
  opts = {},
}
```

---

## Konfiguration

Vollständige Defaults:

```lua
require("emojis").setup({
  default_scope = "%",        -- Scope, wenn keiner angegeben wird
  command       = "Emojis",   -- Name des User-Commands

  -- Einträge des Insert-Pickers: { glyph, label }
  picks = {
    { "✅", "check" }, { "❌", "cross" }, { "⚠️", "warning" }, --[[ … ]]
  },

  -- Codepoint -> :name: für die replace-Aktion
  names = {
    [0x2705] = ":white_check_mark:",
    [0x26A0] = ":warning:",
    -- …
  },

  -- cwd-Suche (ripgrep)
  search = {
    cmd = "rg",
    extra_args = { "--no-heading", "--line-number", "--with-filename", "--color=never" },
  },
})
```

Alle Felder sind optional und werden über die Defaults gemerged.

---

## Anwendungsbeispiele

```vim
:Emojis                  " ganzen Buffer säubern (= clear %)
:Emojis clear line       " nur die aktuelle Zeile
:'<,'>Emojis clear       " markierten Block säubern (Range schlägt Scope)
:Emojis replace %        " Emojis -> :name: im ganzen Buffer
:Emojis list %           " Emojis des Buffers in die Quickfix-Liste
:Emojis count cwd        " projektweit zählen (async, rg)
:Emojis list cwd         " projektweit in die Quickfix-Liste
:Emojis insert           " Emoji-Picker am Cursor
```

---

## Empfohlene Keymaps

```lua
vim.keymap.set({ "n", "i" }, "<C-e>", "<cmd>Emojis insert<cr>", { desc = "Emoji: Picker" })
vim.keymap.set("n", "<leader>ec", "<cmd>Emojis count %<cr>",    { desc = "Emoji: Zählen" })
vim.keymap.set("n", "<leader>el", "<cmd>Emojis list %<cr>",     { desc = "Emoji: Auflisten" })
```

---

## Lua-API

```lua
local emojis = require("emojis")

emojis.setup(opts)   -- konfigurieren + aktivieren (idempotent)
emojis.clear()       -- ganzen Buffer säubern
emojis.count()       -- Emojis im Buffer zählen
emojis.insert()      -- Insert-Picker öffnen
emojis.ops()         -- reine clear/count/list/replace-Funktionen (für Skripte/Tests)
```

Die reinen Operationen arbeiten auf String-Arrays und berühren keine
Neovim-API:

```lua
local ops = require("emojis").ops()
local cleaned, removed = ops.clear({ " 🚀 done" })   -- { " done" }, 1
local n                = ops.count({ "a ⚠️ b" })      -- 1
```

---

## Architektur

```
plugin/emojis.lua          Load-Guard
lua/emojis/
  init.lua                 Öffentliche API, setup()
  @types.lua               LuaLS-Typdefinitionen
  config/
    DEFAULTS.lua           Unveränderliche Default-Konfiguration
    init.lua               Merge + Zugriff auf aktive Config
  util/
    notify.lua             "[emojis] "-präfigierter vim.notify-Wrapper
  core/
    patterns.lua           Reiner UTF-8-Emoji-Tokenizer (Graphemes inkl. VS16)
    ops.lua                Reine clear/count/list/replace-Operationen
    scope.lua              Scope (+ Range) -> Buffer-Zeilenbereich
  actions.lua              Buffer-berührende Handler (edit/list/count)
  picker.lua               Insert-Picker (vim.ui.select)
  search.lua               Asynchrone cwd-Suche (ripgrep)
  commands.lua             :Emojis-Command + Tab-Completion
  health.lua               :checkhealth emojis
```

Reine Logik (`core/*`) ist von allen API-/UI-Schichten getrennt und damit
isoliert testbar.

---

## Health-Check

```
:checkhealth emojis
```

---

## Lizenz

MIT
