-- Make code that jdtls inserts (generate/override actions, multi-line completions) use the
-- buffer's indentation instead of jdtls's default of 4 spaces.
--
-- jdtls takes indentation from the workspace settings java.format.insertSpaces/tabSize (what
-- vscode-java fills from editor.insertSpaces/tabSize). Those are workspace-wide, but Neovim's
-- indent options are per buffer (guess-indent sets them on read), so they're re-sent whenever
-- the current Java buffer's indentation differs from what jdtls last got.
local M = {}

--- java.format settings matching `buf`'s expandtab/shiftwidth (shiftwidth=0 means tabstop).
function M.format_settings(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  return {
    insertSpaces = vim.bo[buf].expandtab,
    tabSize = vim.api.nvim_buf_call(buf, vim.fn.shiftwidth),
  }
end

--- @type table<integer, table> client id -> java.format last sent
local sent = {}

--- Push `buf`'s indentation to its jdtls client, if it changed since the last push.
function M.sync(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local fmt = M.format_settings(buf)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = buf, name = 'jdtls' }) do
    local current = sent[client.id] or vim.tbl_get(client.settings or {}, 'java', 'format')
    if not (current and current.insertSpaces == fmt.insertSpaces and current.tabSize == fmt.tabSize) then
      -- Send the full settings table: jdtls rebuilds its preferences from whatever it receives,
      -- so a partial table would reset everything else (gradle wrapper checksums, ...).
      client.settings = vim.tbl_deep_extend('force', client.settings or {}, { java = { format = fmt } })
      client:notify('workspace/didChangeConfiguration', { settings = client.settings })
    end
    sent[client.id] = fmt
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-jdtls-indent', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client.name == 'jdtls' then
        -- Scheduled so guess-indent's BufReadPost detection has already run.
        vim.schedule(function()
          M.sync(ev.buf)
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = group,
    callback = function(ev)
      sent[ev.data.client_id] = nil
    end,
  })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = '*.java',
    callback = function(ev)
      M.sync(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = { 'expandtab', 'tabstop', 'shiftwidth' },
    callback = function()
      if vim.bo.filetype == 'java' then
        M.sync(0)
      end
    end,
  })
end

return M
