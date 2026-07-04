# emojis.nvim

Ein universeller `:Emojis`-Befehl für Neovim: Emojis **entfernen**, **zählen**,
**auflisten**, **ersetzen** oder **einfügen** — auf verschiedenen Scopes
(aktuelle Zeile, Visual-Auswahl, ganzer Buffer oder projektweit via ripgrep).

Eigenständiges Plugin ohne harte `lib.nvim`-Abhängigkeit, plattformübergreifend.
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
| `unreplace` | Ersetzt `:name:`/`:U+XXXX:`-Platzhalter zurück durch Emojis |
| `wrap` | Umschließt Emojis mit `config.wrap`-Marker, ohne sie zu entfernen |
| `list` | Sammelt alle Emojis im Scope in die Quickfix-Liste |
| `count` | Zählt die Emojis im Scope und meldet das Ergebnis |
| `insert` | Öffnet einen Picker am Cursor zum Einfügen |
| `first` | Springt zum ersten Emoji im Buffer (Cursor-Navigation) |
| `next` | Springt zum nächsten Emoji, wrapt am Bufferende zum Anfang |

| Scope | Beschreibung |
|---|---|
| `%` | Gesamter aktueller Buffer (Standard) |
| `line` | Aktuelle Cursor-Zeile |
| `word` | Zusammenhängender, leerzeichenfreier Textabschnitt unter dem Cursor |
| `visual` | Letzte / aktuelle visuelle Auswahl |
| `cwd` | Projektweit via ripgrep (asynchron; `list`/`count`/`clear`/`replace`) |

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

## Projektweites `clear`/`replace` (`cwd`-Scope)

`:Emojis clear cwd` / `:Emojis replace cwd` durchsuchen das Projekt asynchron
via ripgrep und fragen **vor** jeder Änderung per Bestätigungsdialog nach
(Standard: Abbruch). Empfohlener Ablauf:

```vim
:Emojis list cwd         " Dry-Run: erst prüfen, was betroffen wäre
:Emojis clear cwd        " dann anwenden (Dialog bestätigen)
```

Bereits geöffnete Buffer mit ungespeicherten Änderungen werden übersprungen
(nicht überschrieben) und in der Zusammenfassung als "skipped" gezählt.

---

## Voraussetzungen

- Neovim 0.9+
- `ripgrep` (`rg`) — nur für den `cwd`-Scope optional erforderlich
- [`lib.nvim`](https://github.com/StefanBartl/lib.nvim) — optional; wird für
  `notify`/`map` verwendet, wenn installiert, sonst nativer Fallback (keine
  harte Abhängigkeit)

---

## Installation

### lazy.nvim

```lua
{
  "StefanBartl/emojis.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- optional: nicer notify/map if present
  cmd = "Emojis",
  opts = {},
}
```

### packer.nvim

```lua
use {
  "StefanBartl/emojis.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- optional
  config = function()
    require("emojis").setup()
  end,
}
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim' " optional
Plug 'StefanBartl/emojis.nvim'

lua require("emojis").setup()
```

---

## Konfiguration

Vollständige Defaults:

```lua
require("emojis").setup({
  default_scope = "%",        -- Scope, wenn keiner angegeben wird
  command       = "Emojis",   -- Name des User-Commands

  -- Einträge des Insert-Pickers: { glyph, label }. Beide (picks & names)
  -- werden intern aus demselben Katalog abgeleitet (60+ Einträge) — ein
  -- Label speist sowohl den Picker als auch die replace/unreplace-Map.
  picks = {
    { "✅", "white_check_mark" }, { "❌", "x" }, { "⚠️", "warning" }, --[[ … ]]
  },

  -- Codepoint -> :name: für replace/unreplace (aus `picks` abgeleitet)
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

  -- Opt-in Preset-Keymaps (siehe "Empfohlene Keymaps")
  keymaps = {
    preset = false,
  },

  -- Marker für die `wrap`-Aktion
  wrap = {
    prefix = "[[",
    suffix = "]]",
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
:Emojis unreplace %      " :name: -> Emojis im ganzen Buffer
:Emojis list %           " Emojis des Buffers in die Quickfix-Liste
:Emojis count cwd        " projektweit zählen (async, rg)
:Emojis list cwd         " projektweit in die Quickfix-Liste
:Emojis clear cwd        " projektweit entfernen (Bestätigungsdialog)
:Emojis replace cwd      " projektweit -> :name: (Bestätigungsdialog)
:Emojis insert           " Emoji-Picker am Cursor
:Emojis first            " zum ersten Emoji im Buffer springen
:Emojis next             " zum nächsten Emoji springen (wrapt am Ende)
:Emojis wrap %           " Emojis mit [[ ]] umschließen (Marker konfigurierbar)
```

---

## Empfohlene Keymaps

Per `require("emojis").setup({ keymaps = { preset = true } })` aktivierbar
(Standard: `false`). Labelt die `<leader>e`-Gruppe automatisch in which-key,
falls installiert (`lua/emojis/bindings/which_key.lua`, optionale
Abhängigkeit). Vollständige Übersicht: [`docs/BINDINGS.md`](docs/BINDINGS.md).

| Taste | Modus | Aktion |
|---|---|---|
| `<C-e>` | n, i | Insert-Picker am Cursor |
| `<leader>ec` | n | Emojis im Buffer zählen |
| `<leader>el` | n | Emojis im Buffer -> Quickfix |

Alternativ eigene Keymaps auf `:Emojis` setzen:

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
    notify.lua             Präfigierter Notify-Wrapper (via util/lib.lua)
    lib.lua                Soft-Bridge zu lib.nvim (notify/map), mit Fallback
  core/
    patterns.lua           Reiner UTF-8-Emoji-Tokenizer (Graphemes inkl. VS16)
    ops.lua                Reine clear/count/list/replace-Operationen
    scope.lua              Scope (+ Range) -> Buffer-Zeilenbereich
  bindings/
    init.lua               Orchestriert usrcmds/keymaps/autocmds
    usrcmds.lua            Registriert :Emojis (via commands.lua)
    keymaps.lua            Opt-in Preset-Keymaps (keymaps.preset)
    which_key.lua          Optionales which-key-Gruppenlabel
    autocmds.lua           Leer (bewusst keine Autocmds, siehe ROADMAP)
  actions.lua              Buffer-berührende Handler (edit/list/count)
  nav.lua                  Cursor-Navigation (first/next)
  picker.lua               Insert-Picker (vim.ui.select)
  search.lua               Asynchrone cwd-Suche (ripgrep)
  commands.lua             :Emojis-Dispatch + Tab-Completion
  health.lua               :checkhealth emojis
```

Cheatsheet aller Keymaps/Commands/Autocmds: [`docs/BINDINGS.md`](docs/BINDINGS.md).
Testsuite (rein funktional, headless): [`docs/TESTS/`](docs/TESTS/README.md).

Reine Logik (`core/*`) ist von allen API-/UI-Schichten getrennt und damit
isoliert testbar.

---

## Health-Check

```
:checkhealth emojis
```
