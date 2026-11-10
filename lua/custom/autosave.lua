-- Autosave on navigation: a file is written when you leave it, not while you type.
--
--   BufLeave   the buffer you're leaving (window move into neo-tree / another file, :e, <C-^>,
--              opening Telescope or a terminal)
--   FocusLost  every modified file buffer (cmd-tab away from the terminal)
--   'autowriteall'  :q / :qa / :make write instead of refusing with E37
--   toggling on     writes whatever was left modified while it was off
--
-- Not on InsertLeave: every write runs conform's format_on_save, and reformatting on each <Esc>
-- would shift text mid-edit. Writes use `:update`, so unmodified buffers are never touched.
-- Skipped: non-file buffers (neo-tree, Telescope, help, terminals), unnamed, read-only and
-- .ipynb (jupytext rewrites the notebook JSON on every write).
local M = {}

M.enabled = true

--- Whether autosave should write `buf`.
function M.eligible(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end
  local bo = vim.bo[buf]
  if bo.buftype ~= '' or not bo.modifiable or bo.readonly then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= '' and not name:match '%.ipynb$'
end

--- Write `buf` if autosave is on, it's eligible and modified. Returns true if it's now saved.
function M.save(buf)
  if not (M.enabled and M.eligible(buf) and vim.bo[buf].modified) then
    return false
  end
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd 'silent lockmarks update'
  end)
  if not ok then
    vim.notify(('autosave: %s'):format(err), vim.log.levels.WARN)
  end
  return ok and not vim.bo[buf].modified
end

local function apply()
  vim.o.autowriteall = M.enabled
end

local function save_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.save(buf)
  end
end

function M.toggle()
  M.enabled = not M.enabled
  apply()
  save_all()
  vim.notify('Autosave ' .. (M.enabled and 'on' or 'off'), vim.log.levels.INFO)
end

function M.setup()
  apply()
  local group = vim.api.nvim_create_augroup('custom-autosave', { clear = true })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    callback = function(ev)
      M.save(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd('FocusLost', {
    group = group,
    callback = save_all,
  })
  -- Coming back: pick up files changed on disk meanwhile ('autoread' is on by default, but
  -- only acts when nvim checks).
  vim.api.nvim_create_autocmd('FocusGained', {
    group = group,
    command = 'silent! checktime',
  })
end

return M
