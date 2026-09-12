# Quickstart

Clean the buffer you are in — that is the bare command's default action:

```vim
:Emojis
```

Then narrow the scope, or ask for a different action:

```vim
:Emojis clear line       " only the current line
:Emojis replace %        " emojis -> :name: in the whole buffer
:Emojis list %           " collect every emoji into the quickfix list
:Emojis insert           " searchable picker at the cursor
:Emojis overlay          " quick-insert float of your most-used glyphs
```

Verify your setup any time with:

```vim
:checkhealth emojis
```

The full command surface, with every action/scope combination, is in
[commands.md](commands.md).
