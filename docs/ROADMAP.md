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

- ~~**`replace` rückwärts**~~ — **erledigt.** `:Emojis unreplace` wandelt
  `:name:`/`:U+XXXX:`-Platzhalter zurück in Emojis (inverse Map aus
  `config.names`, `core/ops.lua` `unreplace()`). Unbekannte `:...:`-Tokens
  bleiben unangetastet.

- ~~**`Emojis first` / `Emojis next`**~~ — **erledigt.** `lua/emojis/nav.lua`:
  springt zum ersten/nächsten Emoji im Buffer (Cursor-Navigation statt
  Quickfix), `next` wrapt am Bufferende zum Anfang.

- ~~**`Emojis wrap`**~~ — **erledigt.** `config.wrap.prefix`/`suffix` (Default
  `[[`/`]]`) umgibt jedes Emoji, ohne es zu entfernen (`core/ops.lua`
  `wrap()`, teilt sich `map_spans()` mit `replace()`).

### Scope / Suche

- ~~**Echter `word`-Scope**~~ — **erledigt.** `word` löst jetzt auf den
  leerzeichenfreien Textabschnitt um die Cursor-Byte-Spalte auf
  (`core/scope.lua`), nicht mehr auf die ganze Zeile. `Emojis.Target` trägt
  dafür ein optionales `c1`/`c2`-Byte-Fenster, das `actions.lua` bei
  clear/replace/list/count respektiert.

- ~~**`cwd`-Scope auch für `clear`/`replace`**~~ — **erledigt.**
  `search.lua` `apply_across_files()`: Bestätigungsdialog vor jeder Änderung
  (Standard: Abbruch), `:Emojis list cwd` dient als Dry-Run-Vorschau. Bereits
  geladene Buffer mit ungespeicherten Änderungen werden übersprungen statt
  überschrieben.

- ~~**Glob-/Filetype-Filter für `cwd`**~~ — **erledigt.** Argumente nach dem
  `cwd`-Schlüsselwort (z. B. `:Emojis count cwd *.md`) werden als `--glob`
  an ripgrep durchgereicht (`search.build_cmd()`).

- ~~**Gitignore-Respekt konfigurierbar**~~ — **erledigt.**
  `config.search.no_ignore = true` hängt `--no-ignore` an.

### UX / Integration

- **Telescope-/fzf-Picker** für `insert` — Live-Suche über einen größeren
  Emoji-Katalog statt fixer `vim.ui.select`-Liste; optionale Dependency.

- ~~**Größerer Standard-Emoji-Katalog mit Namen**~~ — **erledigt.**
  `config/DEFAULTS.lua`: ein `CATALOG` aus 60+ `{ glyph, label }`-Einträgen
  speist sowohl `picks` (Insert-Picker) als auch `names` (`replace`/
  `unreplace`) — der Codepoint für `names` wird aus dem Glyph selbst dekodiert
  (`patterns.codepoint`), nicht von Hand eingetragen.

- **Highlight-Vorschau** — vor `clear`/`replace` die betroffenen Emojis kurz
  hervorheben (Extmarks), für visuelles Feedback.

---

## Nicht geplant

- **Emoji-Rendering / Font-Handling** — Sache des Terminals/GUI, nicht des Plugins.
- **Eigene Unicode-Datenbank als Abhängigkeit** — die kompakten Byte-Ranges
  decken den praktischen Bedarf ab; eine vollständige UCD wäre überdimensioniert.
- **Autocmd-getriebenes Auto-Clear beim Speichern** — zu invasiv; bewusst ein
  explizit aufgerufener Befehl (siehe Leitlinie „Event oder Command?").
