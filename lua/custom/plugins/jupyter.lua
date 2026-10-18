-- Jupyter notebooks without a browser: jupytext.nvim turns `.ipynb` into a markdown buffer
-- (markdown cells as plain markdown, code cells as ```python fences) and writes it back on save,
-- markview renders the markdown, otter.nvim gives the code cells Python LSP (pyright + ruff),
-- molten.nvim runs those cells against a real Jupyter kernel and shows the output inline, and
-- image.nvim draws plots in the terminal (Kitty/Ghostty only — elsewhere molten falls back to
-- text output). The same cell keymaps also run `# %%` cells in plain `.py` files.
--
-- molten is a Python remote plugin: it needs pynvim + jupyter_client in Neovim's Python host.
-- install.sh creates a dedicated venv for that at stdpath('data')/molten-venv.
local venv = vim.fn.stdpath 'data' .. '/molten-venv'
if vim.fn.executable(venv .. '/bin/python') == 1 then
  vim.g.python3_host_prog = venv .. '/bin/python'
  -- jupytext.nvim shells out to `jupytext`. Append (not prepend) so the venv's `python` never
  -- shadows the system/project one in :terminal or toggleterm.
  if vim.fn.executable 'jupytext' == 0 then
    vim.env.PATH = vim.env.PATH .. ':' .. venv .. '/bin'
  end
end

local images_supported = (vim.env.KITTY_WINDOW_ID or '') ~= ''
  or vim.env.TERM == 'xterm-kitty'
  or vim.env.TERM == 'xterm-ghostty'
  or vim.env.TERM_PROGRAM == 'ghostty'

local function is_notebook(buf)
  return vim.api.nvim_buf_get_name(buf or 0):match '%.ipynb$' ~= nil
end

-- Cell helpers. Two buffer layouts:
--   markdown (notebooks): a code cell is a ```python fence; the prose between fences is markdown
--     cells and not a navigation/run target. Fences inside jupytext's `<!-- #region -->` blocks
--     are code samples within a markdown cell, not cells.
--   anything else (`.py`): a cell starts at a `# %%` line and runs until the next one (or EOF);
--     anything above the first marker counts as a cell too. `# %% [markdown]` cells never run.
-- Each cell is { head = first line, last = last line, s/e = code lines to run, code = runnable }.
local CELL = '^# %%'
local FENCE_OPEN = '^```%s*python%f[^%w_]'
local FENCE_CLOSE = '^```%s*$'

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function fence_cells(buf_lines)
  local cells, in_region, i = {}, false, 1
  while i <= #buf_lines do
    local l = buf_lines[i]
    if l:match '^<!%-%- #region' then
      in_region = true
    elseif l:match '^<!%-%- #endregion' then
      in_region = false
    elseif not in_region and l:match(FENCE_OPEN) then
      local close = i + 1
      while close <= #buf_lines and not buf_lines[close]:match(FENCE_CLOSE) do
        close = close + 1
      end
      table.insert(cells, { head = i, last = math.min(close, #buf_lines), s = i + 1, e = close - 1, code = true })
      i = close
    end
    i = i + 1
  end
  return cells
end

local function percent_cells(buf_lines)
  local cells = {}
  for i, l in ipairs(buf_lines) do
    if l:match(CELL) then
      table.insert(cells, { head = i, s = i + 1, code = not l:match '%[markdown%]' })
    elseif i == 1 then
      table.insert(cells, { head = 1, s = 1, code = true }) -- code above the first marker
    end
  end
  for n, c in ipairs(cells) do
    c.last = n < #cells and cells[n + 1].head - 1 or #buf_lines
    c.e = c.last
  end
  return cells
end

local function cells(buf_lines)
  return vim.bo.filetype == 'markdown' and fence_cells(buf_lines) or percent_cells(buf_lines)
end

-- The cell holding `lnum`, or nil (markdown prose between fences).
local function cell_at(all, lnum)
  for _, c in ipairs(all) do
    if c.head <= lnum and lnum <= c.last then
      return c
    end
  end
end

-- molten draws output under the last evaluated line; off_by_1 pushes it one further, past the
-- closing ``` fence. In `# %%` buffers that would land past the next cell's marker instead, so
-- keep the (global) option in step with the buffer type.
local function sync_output_offset()
  local want = vim.bo.filetype == 'markdown'
  if vim.g.molten_virt_lines_off_by_1 == want then
    return
  end
  vim.g.molten_virt_lines_off_by_1 = want -- read when molten initializes
  -- Once molten is running it only listens to MoltenUpdateOption. MoltenRunningKernels doesn't
  -- initialize molten, so a buffer switch never starts it as a side effect.
  if vim.fn.exists '*MoltenRunningKernels' == 1 and #vim.fn.MoltenRunningKernels(false) > 0 then
    vim.fn.MoltenUpdateOption('virt_lines_off_by_1', want)
  end
end

-- Runs one cell, skipping markdown cells and cells with nothing but comments/blanks.
local function eval_cell(buf_lines, c)
  if not c.code then
    return
  end
  local s, e = c.s, c.e
  -- Drop trailing blank lines so output lands right under the code, not under the gap.
  while e >= s and not buf_lines[e]:match '%S' do
    e = e - 1
  end
  for i = s, e do
    if buf_lines[i]:match '%S' and not buf_lines[i]:match '^%s*#' then
      sync_output_offset()
      vim.fn.MoltenEvaluateRange(s, e)
      return
    end
  end
end

local function run_cell()
  local buf_lines = lines()
  local c = cell_at(cells(buf_lines), vim.fn.line '.')
  if c then
    eval_cell(buf_lines, c)
  else
    vim.notify('Not in a code cell', vim.log.levels.INFO)
  end
end

-- Runs every cell that starts above `stop` (all cells when `stop` is nil).
local function run_cells(stop)
  local buf_lines = lines()
  for _, c in ipairs(cells(buf_lines)) do
    if stop and c.head >= stop then
      break
    end
    eval_cell(buf_lines, c)
  end
end

-- Jumps to the next/previous cell: its `# %%` marker, or the first code line of a fence.
local function goto_cell(dir)
  local all = cells(lines())
  local cur = vim.fn.line '.'
  local here = cell_at(all, cur)
  local from = dir > 0 and #all or 1
  local to = dir > 0 and 1 or #all
  local target
  for n = to, from, dir > 0 and 1 or -1 do
    local c = all[n]
    if (dir > 0 and c.head > cur) or (dir < 0 and c.head < (here and here.head or cur)) then
      target = c
      break
    end
  end
  if target then
    local fenced = vim.bo.filetype == 'markdown'
    vim.api.nvim_win_set_cursor(0, { fenced and math.min(target.s, target.last) or target.head, 0 })
  end
end

local function run_cell_and_next()
  if cell_at(cells(lines()), vim.fn.line '.') then
    run_cell()
  end
  goto_cell(1)
end

-- Inserts an empty code cell below/above the current one (or the cursor line, in markdown
-- prose) and starts typing in it.
local function new_cell(below)
  local cur = vim.fn.line '.'
  local c = cell_at(cells(lines()), cur)
  local fenced = vim.bo.filetype == 'markdown'
  if below then
    local at = c and c.last or cur
    local new = fenced and { '', '```python', '', '```' } or { '', '# %%', '' }
    vim.api.nvim_buf_set_lines(0, at, at, false, new)
    vim.api.nvim_win_set_cursor(0, { at + 3, 0 })
  else
    local at = (c and c.head or cur) - 1
    local new = fenced and { '```python', '', '```', '' } or { '# %%', '', '' }
    vim.api.nvim_buf_set_lines(0, at, at, false, new)
    vim.api.nvim_win_set_cursor(0, { at + 2, 0 })
  end
  vim.cmd 'startinsert'
end

return {
  { -- Run code against a Jupyter kernel, output shown inline under the cell
    'benlubas/molten-nvim',
    version = '^1.0.0',
    lazy = false, -- remote plugin: its commands come from the rplugin manifest at startup
    build = ':UpdateRemotePlugins',
    dependencies = images_supported and { '3rd/image.nvim' } or {},
    init = function()
      vim.g.molten_image_provider = images_supported and 'image.nvim' or 'none'
      vim.g.molten_auto_open_output = false -- output float only on <leader>mo
      vim.g.molten_virt_text_output = true -- short output as virtual text under the cell
      vim.g.molten_virt_lines_off_by_1 = false -- per buffer type, see sync_output_offset()
      vim.g.molten_wrap_output = true
      vim.g.molten_output_win_max_height = 20
      vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('kickstart-molten-offset', { clear = true }),
        callback = sync_output_offset,
      })
    end,
    config = function()
      local map = function(keys, func, desc, mode)
        vim.keymap.set(mode or 'n', keys, func, { desc = 'Molten: ' .. desc })
      end
      map('<leader>mi', '<cmd>MoltenInit<cr>', '[I]nit kernel (pick)')
      map('<leader>mr', run_cell, '[R]un cell')
      map('<leader>mr', ':<C-u>MoltenEvaluateVisual<cr>gv<Esc>', '[R]un selection', 'v')
      map('<leader>mn', run_cell_and_next, 'Run cell, go to [N]ext')
      map('<leader>ml', '<cmd>MoltenEvaluateLine<cr>', 'Run [L]ine')
      map('<leader>ma', function()
        run_cells()
      end, 'Run [A]ll cells')
      map('<leader>mA', function()
        local c = cell_at(cells(lines()), vim.fn.line '.')
        run_cells(c and c.head or vim.fn.line '.')
      end, 'Run all cells [A]bove')
      map('<leader>mo', '<cmd>noautocmd MoltenEnterOutput<cr>', '[O]pen/enter output')
      map('<leader>mh', '<cmd>MoltenHideOutput<cr>', '[H]ide output')
      map('<leader>md', '<cmd>MoltenDelete<cr>', '[D]elete cell output')
      map('<leader>mx', '<cmd>MoltenInterrupt<cr>', 'Interrupt kernel')
      map('<leader>ms', '<cmd>MoltenRestart!<cr>', 'Re[S]tart kernel')
      map('<leader>mq', '<cmd>MoltenDeinit<cr>', '[Q]uit kernel')
      map('<leader>me', '<cmd>MoltenExportOutput!<cr>', '[E]xport outputs to .ipynb')
      map('<leader>mj', function()
        new_cell(true)
      end, 'New cell below')
      map('<leader>mk', function()
        new_cell(false)
      end, 'New cell above')
      map(']x', function()
        goto_cell(1)
      end, 'Next cell')
      map('[x', function()
        goto_cell(-1)
      end, 'Previous cell')
    end,
  },
  { -- Open .ipynb as markdown with ```python code cells, write it back as .ipynb on save
    'GCBallesteros/jupytext.nvim',
    lazy = false, -- must register its *.ipynb read/write autocmds before the first open
    opts = { style = 'markdown', output_extension = 'md', force_ft = 'markdown' },
    config = function(_, opts)
      -- jupytext.nvim json-decodes the notebook unguarded, so a missing or empty `.ipynb` (e.g.
      -- one just created with neo-tree's `a`) errors out. Seed those with an empty Python 3
      -- notebook first — the `jupytext` CLI needs a valid file on disk too.
      local utils = require 'jupytext.utils'
      local get_metadata = utils.get_ipynb_metadata
      utils.get_ipynb_metadata = function(filename)
        local path = vim.fn.resolve(vim.fn.expand(filename))
        if vim.fn.getfsize(path) <= 0 then
          vim.fn.writefile({
            vim.json.encode {
              cells = {},
              metadata = {
                kernelspec = { display_name = 'Python 3', language = 'python', name = 'python3' },
                language_info = { name = 'python' },
              },
              nbformat = 4,
              nbformat_minor = 5,
            },
          }, path)
        end
        return get_metadata(filename)
      end
      require('jupytext').setup(opts)
    end,
  },
  { -- LSP (pyright + ruff: completion, hover, diagnostics, go-to) inside a notebook's code cells
    'jmbuhr/otter.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    lazy = false, -- its FileType autocmd below must exist before the first notebook opens
    opts = {
      -- Default is BufWritePost only; refresh pyright/ruff diagnostics while editing too.
      lsp = { diagnostic_update_events = { 'BufWritePost', 'InsertLeave', 'TextChanged' } },
    },
    config = function(_, opts)
      require('otter').setup(opts)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('kickstart-otter', { clear = true }),
        pattern = 'markdown',
        callback = function(ev)
          -- Notebooks only: plain .md files (READMEs, notes) don't get a pyright per code block.
          if is_notebook(ev.buf) then
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(ev.buf) then
                vim.api.nvim_buf_call(ev.buf, function()
                  require('otter').activate { 'python' }
                end)
              end
            end)
          end
        end,
      })
    end,
  },
  { -- Inline images (plots) via the Kitty graphics protocol
    '3rd/image.nvim',
    cond = images_supported,
    opts = {
      backend = 'kitty',
      processor = 'magick_cli', -- uses the `magick` binary, no luarocks needed
      integrations = {}, -- markdown rendering is markview's job
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
    },
  },
}
