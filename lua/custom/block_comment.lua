-- `/* … */` block comments for the built-in `gc` / `gcc` (vim._comment), which only knows the
-- filetype's line-comment 'commentstring'. Attached to Java buffers from
-- lua/custom/plugins/java.lua.
--
--   gcc / gc{motion} / visual gc on a standalone /* */ block   -> removes its delimiters
--   gc over several uncommented lines                          -> /* and */ on their own lines
--   gcc on one line, or lines that are all `//` comments       -> built-in `//` toggle
--   gc (operator-pending) inside a /* */ block                 -> selects it: dgc, gcgc
--
-- "Standalone" means the comment owns its lines: nothing but indentation before `/*` and nothing
-- after `*/`. Javadoc (`/**`) and trailing comments (`foo(); /* x */`) are never touched; a range
-- overlapping one falls back to the built-in toggle. Needs the filetype's treesitter parser;
-- without it everything falls back to the built-in.
local M = {}

-- Treesitter node type of a block comment, per language. Add a language here and call attach()
-- from its FileType autocmd to extend this beyond Java.
M.node_types = { java = 'block_comment' }

local builtin = require 'vim._comment'

local function blank(s)
  return s:match '^%s*$' ~= nil
end

local function set_lines(buf, from, to, lines)
  -- Same as vim._comment: lockmarks keeps regular marks from collapsing onto the edited range.
  vim._with({ lockmarks = true }, function()
    vim.api.nvim_buf_set_lines(buf, from, to, false, lines)
  end)
end

--- Block comments overlapping 1-based lines l1..l2, as { s, e, ok } with 0-based rows s..e.
--- `ok` = standalone and not Javadoc, i.e. something this module may uncomment.
---@return { s: integer, e: integer, ok: boolean }[]
local function find_blocks(buf, l1, l2)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  local node_type = lang and M.node_types[lang]
  local parser = node_type and vim.treesitter.get_parser(buf, lang, { error = false })
  if not parser then
    return {}
  end
  local root = parser:parse()[1]:root()
  local query = vim.treesitter.query.parse(lang, '(' .. node_type .. ') @c')

  local blocks = {}
  for _, node in query:iter_captures(root, buf, l1 - 1, l2) do
    local sr, sc, er, ec = node:range()
    if sr <= l2 - 1 and er >= l1 - 1 then
      local first = vim.api.nvim_buf_get_lines(buf, sr, sr + 1, false)[1]
      local last = vim.api.nvim_buf_get_lines(buf, er, er + 1, false)[1]
      local standalone = (first:find '%S' or 0) - 1 == sc and blank(last:sub(ec + 1))
      local doc = first:sub(sc + 1, sc + 3) == '/**' and first:sub(sc + 1, sc + 4) ~= '/**/'
      table.insert(blocks, { s = sr, e = er, ok = standalone and not doc })
    end
  end
  return blocks
end

--- Strip the delimiters (and a ` * ` decoration column) from the block on 0-based rows s..e.
local function uncomment(buf, s, e)
  local lines = vim.api.nvim_buf_get_lines(buf, s, e + 1, false)
  local n = #lines
  local drop = {}

  local indent, rest = lines[1]:match '^(%s*)/%*%s?(.*)$'
  lines[1] = indent .. rest
  if blank(rest) then
    drop[1] = true
  end

  -- Middle lines all starting with `*` are the decorated style: strip the column back to the
  -- indent of the `/*` line.
  local decorated = n > 2
  for i = 2, n - 1 do
    if not blank(lines[i]) and not (lines[i]:match '^%s*%*' and not lines[i]:match '^%s*%*/') then
      decorated = false
      break
    end
  end
  if decorated then
    for i = 2, n - 1 do
      local text = lines[i]:match '^%s*%*%s?(.*)$'
      lines[i] = text and not blank(text) and indent .. text or ''
    end
  end

  local pre = lines[n]:match '^(.-)%s?%*/%s*$'
  if blank(pre) then
    drop[n] = true
  else
    lines[n] = pre
  end

  local out = {}
  for i, line in ipairs(lines) do
    if not drop[i] then
      table.insert(out, line)
    end
  end
  set_lines(buf, s, e + 1, out)
end

--- 'operatorfunc' for gc / gcc; called with no argument from the expr mappings to arm it.
---@param mode string?
function M.operator(mode)
  if mode == nil then
    vim.o.operatorfunc = "v:lua.require'custom.block_comment'.operator"
    return 'g@'
  end

  local buf = vim.api.nvim_get_current_buf()
  local l1, c1 = vim.fn.line "'[", vim.fn.col "'["
  local l2, c2 = vim.fn.line "']", vim.fn.col "']"
  if l1 > l2 or (l1 == l2 and c1 > c2) then
    return
  end
  local function fallback()
    builtin.toggle_lines(l1, l2, vim.api.nvim_win_get_cursor(0))
  end

  local blocks = find_blocks(buf, l1, l2)
  local ours = vim.tbl_filter(function(b)
    return b.ok
  end, blocks)
  if #ours > 0 then
    -- Bottom to top, so rows of the blocks above stay valid.
    for i = #ours, 1, -1 do
      uncomment(buf, ours[i].s, ours[i].e)
    end
    return
  end
  if #blocks > 0 or l1 == l2 then
    return fallback()
  end

  local lines = vim.api.nvim_buf_get_lines(buf, l1 - 1, l2, false)
  local indent, all_line_comments, nonblank = nil, true, false
  for _, line in ipairs(lines) do
    if line:find('*/', 1, true) then
      -- Block comments don't nest: the first `*/` would end the wrapper early.
      return fallback()
    end
    if not blank(line) then
      nonblank = true
      all_line_comments = all_line_comments and line:match '^%s*//' ~= nil
      local ws = line:match '^%s*'
      if not indent or #ws < #indent then
        indent = ws
      end
    end
  end
  if not nonblank or all_line_comments then
    return fallback()
  end

  table.insert(lines, 1, indent .. '/*')
  table.insert(lines, indent .. '*/')
  set_lines(buf, l1 - 1, l2, lines)
end

--- `gc` text object: the standalone block comment around the cursor, else the built-in one
--- (contiguous `//` lines).
function M.textobject()
  local lnum = vim.fn.line '.'
  for _, b in ipairs(find_blocks(0, lnum, lnum)) do
    if b.ok then
      vim.cmd(('normal! %dGV%dG'):format(b.s + 1, b.e + 1))
      return
    end
  end
  builtin.textobject()
end

--- Buffer-local gc / gcc / gc-textobject, mirroring the built-in maps in vim/_core/defaults.lua.
function M.attach(buf)
  local function map(mode, lhs, rhs, desc, expr)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, expr = expr, desc = desc })
  end
  map({ 'n', 'x' }, 'gc', M.operator, 'Toggle comment (/* */ for several lines)', true)
  map('n', 'gcc', function()
    return M.operator() .. '_'
  end, 'Toggle comment line', true)
  map('o', 'gc', M.textobject, 'Comment textobject (incl. /* */ blocks)')
end

return M
