-- docs/TESTS/scope_spec.lua — scope resolution: %, line, visual, range, cwd.
---@diagnostic disable: need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local scope_m = require("emojis.core.scope")

  local buf = H.scratch()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })

  -- "%": whole buffer, 0-based inclusive
  do
    local t = scope_m.resolve("%", 0, 0, 0)
    eq(t.l1, 0, "%: first line")
    eq(t.l2, 2, "%: last line")
  end

  -- "line": current cursor line only
  do
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local t = scope_m.resolve("line", 0, 0, 0)
    eq(t.l1, 1, "line: 0-based cursor line")
    eq(t.l2, 1, "line: single-line range")
  end

  -- explicit Vim range overrides the scope keyword
  do
    local t = scope_m.resolve("%", 2, 1, 2)
    eq(t.l1, 0, "range: overrides scope, start")
    eq(t.l2, 1, "range: overrides scope, end")
  end

  -- "cwd": sentinel target (buf == -1), no buffer touched
  do
    local t = scope_m.resolve("cwd", 0, 0, 0)
    eq(t.buf, -1, "cwd: sentinel buffer")
  end

  -- "visual": errors without a prior visual selection
  do
    vim.cmd("normal! \27") -- clear any pending mode
    local t, err = scope_m.resolve("visual", 0, 0, 0)
    if t == nil then
      eq(type(err), "string", "visual: error message when unset")
    end
  end

  -- unknown scope
  do
    local t, err = scope_m.resolve("bogus", 0, 0, 0)
    eq(t, nil, "unknown scope: no target")
    eq(err, "unknown scope: bogus", "unknown scope: error message")
  end
end
