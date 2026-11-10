-- Browser-style closing/reopening of bufferline's buffer tabs.
--
-- `close()` deletes the current buffer and shows the tab you used before it (most recently used
-- order, like a browser returning to the previous tab), not bufferline's neighbour. Windows that
-- showed the buffer keep existing, so splits and neo-tree stay where they are (unlike `:bd`).
-- `reopen()` brings back the last closed file, like Ctrl+Shift+T; closed tabs form a stack.
local M = {}

--- @type integer[] listed file buffers, most recently entered first
local mru = {}
--- @type { path: string, cursor: integer[] }[] closed files, most recent last
local closed = {}
local MAX_CLOSED = 50

--- A "tab": a listed, normal (file or unnamed) buffer — not neo-tree, trouble, help, terminals.
local function is_tab(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == ''
end

local function forget(buf)
  for i = #mru, 1, -1 do
    if mru[i] == buf then
      table.remove(mru, i)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-tabs', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(ev)
      if is_tab(ev.buf) then
        forget(ev.buf)
        table.insert(mru, 1, ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(ev)
      forget(ev.buf)
    end,
  })
  -- The buffer nvim started on was entered before this autocmd existed.
  local cur = vim.api.nvim_get_current_buf()
  if is_tab(cur) then
    forget(cur)
    table.insert(mru, 1, cur)
  end
end

--- The tab to show once `buf` is gone.
local function previous_tab(buf)
  for _, b in ipairs(mru) do
    if b ~= buf and is_tab(b) then
      return b
    end
  end
  local alt = vim.fn.bufnr '#'
  if alt > 0 and alt ~= buf and is_tab(alt) then
    return alt
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= buf and is_tab(b) then
      return b
    end
  end
  return vim.api.nvim_create_buf(true, false)
end

--- Close the current tab and go back to the previously used one.
function M.close()
  local buf = vim.api.nvim_get_current_buf()
  if not is_tab(buf) then
    vim.notify('Not a buffer tab', vim.log.levels.INFO)
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].modified then
    local display = name ~= '' and vim.fn.fnamemodify(name, ':~:.') or '[No Name]'
    local choice = vim.fn.confirm(('Save changes to %s?'):format(display), '&Yes\n&No\n&Cancel', 1)
    if choice == 1 then
      local ok, err = pcall(vim.cmd.write)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
    elseif choice ~= 2 then
      return
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local target = previous_tab(buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_win_set_buf(win, target)
    end
  end

  if name ~= '' then
    table.insert(closed, { path = name, cursor = cursor })
    if #closed > MAX_CLOSED then
      table.remove(closed, 1)
    end
  end
  -- Other tabpages may still show it; nvim_buf_delete closes those windows, which is what :bd does.
  vim.api.nvim_buf_delete(buf, { force = true })
end

--- Reopen the most recently closed tab.
function M.reopen()
  while #closed > 0 do
    local entry = table.remove(closed)
    if vim.uv.fs_stat(entry.path) then
      vim.cmd.edit(vim.fn.fnameescape(entry.path))
      local line = math.min(math.max(entry.cursor[1], 1), vim.api.nvim_buf_line_count(0))
      pcall(vim.api.nvim_win_set_cursor, 0, { line, entry.cursor[2] })
      return
    end
  end
  vim.notify('No closed tabs to reopen', vim.log.levels.INFO)
end

return M
