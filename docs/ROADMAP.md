# emojis.nvim — Roadmap

## Implemented (v0.1)

- `:Emojis [action] [scope]` — clear / replace / list / count / insert
- Scopes: `%`, `line`, `word`, `visual`, `cwd` (async ripgrep)
- Vim range overrides the scope keyword
- **Space-collapse on clear** — ` 🚀 ` → ` ` (single space), incl. emoji runs
- **VS16 grapheme handling** — ⚠️ counted once, replaced as one placeholder
- Configurable picks, name map, command name, ripgrep invocation
- Context-aware tab completion
- Pure, testable core (`patterns`, `ops`) separated from API/UI
- `config/DEFAULTS.lua` config system, idempotent `setup()`
- `:checkhealth emojis`
- No hard lib.nvim dependency (optional soft bridge for notify/map)
- `bindings/` module (usrcmds/keymaps/autocmds) with opt-in preset keymaps
  (`keymaps.preset`) and which-key group label
- `docs/BINDINGS.md` cheatsheet, `docs/TESTS/` headless spec suite

---

## Geplante Features

### Emoji-Abdeckung

- ~~**Vollständigere Unicode-Abdeckung**~~ — **erledigt.** Tabellengetriebene
  Range-Liste (`core/patterns.lua`: `RANGES` + `range_pattern()`) statt fixer
  Patterns; zusätzlich U+2300–23FF (Misc Technical: ⌚⏰⏳). Das
  1F000–1FFFF-Band deckt Enclosed Alphanumeric Supplement (inkl.
  Regional-Indicator-Flaggen) und Dingbats bereits vollständig ab.

- ~~**ZWJ-Sequenzen & Hautton-Modifikatoren**~~ — **erledigt.** Zero-Width-Joiner
  (U+200D)-Ketten (👨‍👩‍👧), Fitzpatrick-Modifikatoren (U+1F3FB–1F3FF, 👍🏽)
  und gepaarte Regional-Indicator-Flaggen (🇩🇪) werden als je ein Graphem
  behandelt — wirkt sich auf `count`/`clear`/`list`/`replace` gleichermaßen aus.

### Aktionen

- **`replace` rückwärts** — `:Emojis unreplace` wandelt `:name:`-Platzhalter
  zurück in Emojis (inverse Map aus `config.names`).

- **`Emojis first` / `Emojis next`** — zum nächsten Emoji im Buffer springen
  (Cursor-Navigation statt Quickfix).

- **`Emojis wrap`** — Emojis mit konfigurierbarem Marker umgeben (z. B. für
  spätere maschinelle Verarbeitung), ohne sie zu entfernen.

### Scope / Suche

- ~~**Echter `word`-Scope**~~ — **erledigt.** `word` löst jetzt auf den
  leerzeichenfreien Textabschnitt um die Cursor-Byte-Spalte auf
  (`core/scope.lua`), nicht mehr auf die ganze Zeile. `Emojis.Target` trägt
  dafür ein optionales `c1`/`c2`-Byte-Fenster, das `actions.lua` bei
  clear/replace/list/count respektiert.

- **`cwd`-Scope auch für `clear`/`replace`** — projektweites Entfernen/Ersetzen
  mit Bestätigungsdialog und optionalem Dry-Run (Quickfix-Vorschau zuerst).

- **Glob-/Filetype-Filter für `cwd`** — `:Emojis count cwd *.md` nur in
  bestimmten Dateien; Weiterreichen zusätzlicher rg-Globs.

- **Gitignore-Respekt konfigurierbar** — rg respektiert `.gitignore` bereits;
  Option `--no-ignore` für vollständige Suche.

### UX / Integration

- **Telescope-/fzf-Picker** für `insert` — Live-Suche über einen größeren
  Emoji-Katalog statt fixer `vim.ui.select`-Liste; optionale Dependency.

- **Größerer Standard-Emoji-Katalog mit Namen** — vollständige `:name:`-Map
  (Shortcode-Tabelle), für `replace` und einen Such-Picker gemeinsam genutzt.

- **Highlight-Vorschau** — vor `clear`/`replace` die betroffenen Emojis kurz
  hervorheben (Extmarks), für visuelles Feedback.

---

## Nicht geplant

- **Emoji-Rendering / Font-Handling** — Sache des Terminals/GUI, nicht des Plugins.
- **Eigene Unicode-Datenbank als Abhängigkeit** — die kompakten Byte-Ranges
  decken den praktischen Bedarf ab; eine vollständige UCD wäre überdimensioniert.
- **Autocmd-getriebenes Auto-Clear beim Speichern** — zu invasiv; bewusst ein
  explizit aufgerufener Befehl (siehe Leitlinie „Event oder Command?").
