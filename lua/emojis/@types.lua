---@meta
---@module 'emojis.@types'
---@brief Type definitions for emojis.nvim.
---@description
--- Central type catalog so the source files stay free of long annotation blocks.
--- All `@types` modules return an empty table.

-- #####################################################################
-- command surface
-- #####################################################################

---@alias Emojis.Action
---| '"clear"'      # Remove all emojis from scope (collapses surrounding spaces)
---| '"insert"'     # Open a picker and insert an emoji at the cursor
---| '"list"'       # Collect all emojis in scope into the quickfix list
---| '"count"'      # Count emojis in scope and report via notify
---| '"replace"'    # Replace emojis with :name: placeholders
---| '"unreplace"'  # Replace :name:/:U+XXXX: placeholders back with emojis
---| '"first"'      # Move the cursor to the first emoji in the buffer
---| '"next"'       # Move the cursor to the next emoji (wraps to the top)
---| '"wrap"'       # Surround each emoji with config.wrap.prefix/suffix
---| '"overlay"'    # Open the frecency-ordered quick-insert overlay
---| '"toggle"'     # Cycle the emoji checkbox on the current line / range

---@alias Emojis.Scope
---| '"word"'    # Current line (the line holding the word under the cursor)
---| '"line"'    # Current line (cursor line)
---| '"visual"'  # Last / current visual selection
---| '"%"'       # Whole current buffer
---| '"cwd"'     # All files under cwd (ripgrep-based, async; list/count only)

---@class Emojis.Target
--- A resolved scope: a buffer and an inclusive 0-based line range.
--- `buf == -1` is the sentinel for the cwd (whole-project) scope.
--- `c1`/`c2` (1-based inclusive byte columns, `l1 == l2` only) restrict the
--- scope to a substring of that single line — set by the `word` scope.
---@field buf integer
---@field l1  integer      First line, 0-based inclusive
---@field l2  integer      Last line, 0-based inclusive
---@field c1  integer|nil  First byte column, 1-based inclusive
---@field c2  integer|nil  Last byte column, 1-based inclusive

---@class Emojis.Span
--- One emoji grapheme located inside a line (1-based byte offsets).
---@field [1] integer  Start byte (1-based, inclusive)
---@field [2] integer  End byte (1-based, inclusive; includes a trailing VS16)

---@class Emojis.ListEntry
---@field lnum integer  1-based absolute line number
---@field col  integer  0-based byte column
---@field text string   The emoji glyph

-- #####################################################################
-- config
-- #####################################################################

---@class Emojis.Config.PickEntry
---@field [1] string  The emoji glyph
---@field [2] string  Short label shown in the picker

---@class Emojis.Config.Search
---@field cmd        string    External search binary (default "rg")
---@field extra_args string[]  Extra args appended before the pattern
---@field no_ignore  boolean   Pass --no-ignore so rg also searches gitignored files

---@class Emojis.Config.Keymaps
---@field preset boolean  Bind the opt-in preset keymaps (default false)

---@class Emojis.Config.Wrap
---@field prefix string  Text inserted before each emoji by `wrap`
---@field suffix string  Text inserted after each emoji by `wrap`

---@class Emojis.Config.Preview
---@field enable      boolean  Highlight affected emojis before clear/replace (default false)
---@field duration_ms integer  How long to show the highlight before mutating
---@field hl_group    string   Highlight group used for the preview extmarks

---@alias Emojis.Config.Picker.Engine
---| '"auto"'      # Try telescope.nvim, then fzf-lua, then vim.ui.select
---| '"telescope"' # telescope.nvim only, falling back to vim.ui.select
---| '"fzf-lua"'   # fzf-lua only, falling back to vim.ui.select
---| '"select"'    # Always use vim.ui.select

---@class Emojis.Config.Picker
---@field engine Emojis.Config.Picker.Engine  Insert-picker engine (default "auto")

---@class Emojis.Config.Checkbox
---@field default_set string                    Set used by `:Emojis toggle` with no argument; "" = search all
---@field sets        table<string, string[]>   Named cycles; order within a set is the cycle order
---@field order       string[]                  Search order across sets (ambiguity resolution)

---@alias Emojis.Config.Overlay.Mode
---| '"grid"'       # 2D grid, hjkl/arrows + <CR> (default)
---| '"grid_keys"'  # 2D grid with a direct hotkey per cell
---| '"list"'       # One glyph per row, via the kit chooser

---@class Emojis.Config.Overlay
---@field mode     Emojis.Config.Overlay.Mode  Interaction mode (default "grid")
---@field picks    Emojis.Config.PickEntry[]   Curated quick-insert set, in starting order
---@field frecency boolean                     Reorder `picks` by recorded usage (default true)
---@field columns  integer                     Cells per row in the grid modes (default 5)
---@field limit    integer                     Maximum cells shown (default 20)
---@field title    string                      Float title
---@field theme    any                         lib.nvim.ui.kit theme arg (preset name or override table)

---@class Emojis.Config
---@field default_scope Emojis.Scope                      Scope used when none is given
---@field command       string                            Name of the user command
---@field picks         Emojis.Config.PickEntry[]         Entries for the insert picker
---@field names         table<integer, string>            Codepoint -> :name: for replace
---@field search        Emojis.Config.Search              cwd search configuration
---@field keymaps       Emojis.Config.Keymaps              Opt-in preset keymaps
---@field wrap          Emojis.Config.Wrap                 Marker for the wrap action
---@field preview       Emojis.Config.Preview              Opt-in clear/replace highlight preview
---@field picker        Emojis.Config.Picker               Insert-picker engine selection
---@field overlay       Emojis.Config.Overlay              Quick-insert overlay
---@field checkbox      Emojis.Config.Checkbox             Emoji checkbox cycles

return {}
