# emojis.nvim — Roadmap

## Status

All originally planned features are implemented as of v0.3.0: the core
`:Emojis [action] [scope]` command surface (clear/replace/unreplace/wrap/
list/count/insert/first/next), the `cwd` project-wide scope, the
telescope/fzf-lua insert picker, the frecency-ordered quick-insert overlay,
and the emoji checkbox cycle (`toggle`/`checkbox_add`/`checkbox_remove` +
the cascade.nvim bridge via `cascade_groups()`). See `docs/architecture.md`
for the module layout and `docs/BINDINGS.md` for the full binding surface.

There is currently no open feature work. This file stays here — and gets
updated first — the moment new work starts.

---

## Nicht geplant

- **Emoji rendering / font handling** — a matter for the terminal/GUI, not the plugin.
- **Eigene Unicode-Datenbank als Abhängigkeit** — die kompakten Byte-Ranges
  cover the practical need; a complete UCD would be overkill.
- **Autocmd-driven auto-clear on save** — too invasive; deliberately a command
  invoked explicitly (see the guideline "event or command?").
