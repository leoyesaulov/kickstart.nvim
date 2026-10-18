-- Jupyter notebooks without a browser: jupytext.nvim turns `.ipynb` into a plain `# %%`
-- (percent-style) Python buffer and writes it back on save, molten.nvim runs those cells
-- against a real Jupyter kernel and shows the output inline, and image.nvim draws plots in the
-- terminal (Kitty/Ghostty only — elsewhere molten falls back to text output).
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

-- Cell helpers. A cell starts at a `# %%` line and runs until the next one (or EOF); anything
-- above the first marker counts as a cell too.
local CELL = '^# %%'

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Returns header (marker line, or 1 if there is none) and last line of the cell holding `lnum`.
local function cell_bounds(buf_lines, lnum)
  local s, e = lnum, lnum
  while s > 1 and not buf_lines[s]:match(CELL) do
    s = s - 1
  end
  while e < #buf_lines and not buf_lines[e + 1]:match(CELL) do
    e = e + 1
  end
  return s, e
end

-- Runs one cell, skipping `# %% [markdown]` cells and cells with nothing but comments/blanks.
local function eval_cell(buf_lines, s, e)
  if buf_lines[s]:match(CELL) then
    if buf_lines[s]:match '%[markdown%]' then
      return
    end
    s = s + 1
  end
  for i = s, e do
    if buf_lines[i]:match '%S' and not buf_lines[i]:match '^%s*#' then
      vim.fn.MoltenEvaluateRange(s, e)
      return
    end
  end
end

local function run_cell()
  local buf_lines = lines()
  eval_cell(buf_lines, cell_bounds(buf_lines, vim.fn.line '.'))
end

-- Runs every cell whose header is above `stop` (all cells when `stop` is nil).
local function run_cells(stop)
  local buf_lines = lines()
  local lnum = 1
  while lnum <= #buf_lines and (not stop or lnum < stop) do
    local s, e = cell_bounds(buf_lines, lnum)
    eval_cell(buf_lines, s, e)
    lnum = e + 1
  end
end

local function goto_cell(dir)
  local buf_lines = lines()
  local cur = vim.fn.line '.'
  if dir > 0 then
    for i = cur + 1, #buf_lines do
      if buf_lines[i]:match(CELL) then
        return vim.api.nvim_win_set_cursor(0, { i, 0 })
      end
    end
  else
    local s = cell_bounds(buf_lines, cur)
    for i = s - 1, 1, -1 do
      if buf_lines[i]:match(CELL) then
        return vim.api.nvim_win_set_cursor(0, { i, 0 })
      end
    end
  end
end

local function run_cell_and_next()
  run_cell()
  goto_cell(1)
end

-- Inserts an empty `# %%` cell below/above the current one and starts typing in it.
local function new_cell(below)
  local buf_lines = lines()
  local s, e = cell_bounds(buf_lines, vim.fn.line '.')
  if below then
    vim.api.nvim_buf_set_lines(0, e, e, false, { '', '# %%', '' })
    vim.api.nvim_win_set_cursor(0, { e + 3, 0 })
  else
    vim.api.nvim_buf_set_lines(0, s - 1, s - 1, false, { '# %%', '', '' })
    vim.api.nvim_win_set_cursor(0, { s + 1, 0 })
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
      vim.g.molten_virt_lines_off_by_1 = true -- ...placed after the cell's last line
      vim.g.molten_wrap_output = true
      vim.g.molten_output_win_max_height = 20
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
        run_cells(cell_bounds(lines(), vim.fn.line '.'))
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
  { -- Open .ipynb as `# %%` Python, write it back as .ipynb on save
    'GCBallesteros/jupytext.nvim',
    lazy = false, -- must register its *.ipynb read/write autocmds before the first open
    opts = { style = 'percent', output_extension = 'auto' },
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
