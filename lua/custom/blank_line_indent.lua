-- The first character typed on an empty line gets the indent the context calls for, before it's
-- inserted. Vim drops autoindent from a line left empty, so `i` on a blank line in a method body
-- starts at column 0. Anything typed there (a snippet trigger, a completion, plain code) would stay
-- at column 0, and LuaSnip would indent every later line of a multi-line snippet from there too.
--
-- Done in InsertCharPre by prepending the indent to v:char. Buffer edits aren't allowed there
-- (textlock), but Vim inserts a changed v:char literally and records it for `.`.
-- Typing <Space>/<Tab> is left alone (you're indenting by hand), and so is a line that already
-- has whitespace you put there, unless it's just the start of the indent wanted.
-- Wired up in init.lua.
local M = {}

-- Filetypes where indentation has meaning, or where there's no code indent to follow.
M.excluded = { python = true, yaml = true, make = true, markdown = true, text = true, gitcommit = true, [''] = true }

--- The indent `buf`'s indent rules want for line `lnum`, in columns, or nil if it has none.
function M.desired_indent(buf, lnum)
  local bo = vim.bo[buf]
  local ok, cols
  if bo.indentexpr ~= '' then
    vim.v.lnum = lnum
    ok, cols = pcall(vim.fn.eval, bo.indentexpr)
  elseif bo.cindent then
    ok, cols = pcall(vim.fn.cindent, lnum)
  elseif bo.lisp then
    ok, cols = pcall(vim.fn.lispindent, lnum)
  end
  cols = ok and tonumber(cols)
  return cols and cols >= 0 and cols or nil
end

--- `cols` columns of indent as `buf` writes it: tabs (+ spaces) with noexpandtab, else spaces.
function M.indent_string(cols, buf)
  if vim.bo[buf].expandtab then
    return (' '):rep(cols)
  end
  local ts = vim.bo[buf].tabstop
  return ('\t'):rep(math.floor(cols / ts)) .. (' '):rep(cols % ts)
end

--- What to insert before the typed char on whitespace-only `line` (cursor at its end) to reach
--- `cols` columns of indent, or nil to leave it: the line already has that much, isn't blank, or
--- has whitespace that isn't the start of the wanted indent.
function M.prefix_for(line, cols, buf)
  if not cols or line:find '%S' then
    return nil
  end
  local want = M.indent_string(cols, buf)
  if #line < #want and want:sub(1, #line) == line then
    return want:sub(#line + 1)
  end
end

local function on_char()
  local char = vim.v.char
  if vim.v.insertmode ~= 'i' or char == '' or char:find '^%s' then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local bo = vim.bo[buf]
  if bo.buftype ~= '' or not bo.modifiable or M.excluded[bo.filetype] then
    return
  end
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if col ~= #line or line:find '%S' then
    return
  end
  local prefix = M.prefix_for(line, M.desired_indent(buf, row), buf)
  if prefix then
    vim.v.char = prefix .. char
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('InsertCharPre', {
    group = vim.api.nvim_create_augroup('custom-blank-line-indent', { clear = true }),
    callback = on_char,
  })
end

return M
