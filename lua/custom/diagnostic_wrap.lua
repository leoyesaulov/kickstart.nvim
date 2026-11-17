-- Fit diagnostic messages on screen: `format` for vim.diagnostic's built-in `virtual_lines`
-- handler that word-wraps the message to the space left in the window.
--
-- End-of-line `virtual_text` is never wrapped by Neovim (long messages are cut off at the window
-- edge). `virtual_lines` draws the message on lines below the code and splits it on "\n", so
-- inserting newlines at the right width makes the whole message visible. The handler starts the
-- text at the diagnostic's column behind a `└──── ` connector; the width left after that is
-- what the message is wrapped to.
--
-- The wrap width is computed when diagnostics are drawn, so setup() redraws them when a window
-- showing the buffer is resized (splits, :vertical resize, terminal resize).
--
-- Known gap: a diagnostic far right in a narrow window leaves less than MIN_WIDTH columns; the
-- message is then wrapped at MIN_WIDTH and runs past the edge. `<C-w>d` (float) always wraps.
local M = {}

-- Never wrap narrower than this; below it a message becomes an unreadable column of fragments.
M.MIN_WIDTH = 20

-- Width of the `└──── ` connector the virtual_lines handler puts before the message.
local CONNECTOR_WIDTH = 6

--- Text columns available to a virtual line in the narrowest window showing `bufnr`.
local function text_width(bufnr)
  local width
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    local info = vim.fn.getwininfo(win)[1]
    local w = info.width - info.textoff
    if not width or w < width then
      width = w
    end
  end
  return width or vim.o.columns
end

--- Display width of `bufnr`'s line `lnum` (0-based) before byte column `col` (0-based).
local function indent_width(bufnr, lnum, col)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
  return vim.fn.strdisplaywidth(line:sub(1, math.min(col, #line)))
end

--- Word-wrap `text` to lines of at most `width` display cells. Existing newlines are kept and
--- words longer than `width` are split. A line's leading indent is kept on its continuations.
function M.wrap(text, width)
  local out = {}
  local full_width = width
  for _, para in ipairs(vim.split(text, '\n', { plain = true })) do
    local lead = para:match '^%s*'
    if vim.fn.strdisplaywidth(lead) > full_width / 2 then
      lead = ''
    end
    width = full_width - vim.fn.strdisplaywidth(lead)
    local first = #out + 1
    local line = ''
    for word in para:gmatch '%S+' do
      while vim.fn.strdisplaywidth(word) > width do
        if line ~= '' then
          table.insert(out, line)
          line = ''
        end
        local n = vim.fn.strcharlen(word)
        local cut = width
        -- Shrink for wide (CJK) characters until the piece fits.
        while cut > 1 and vim.fn.strdisplaywidth(vim.fn.strcharpart(word, 0, cut)) > width do
          cut = cut - 1
        end
        table.insert(out, vim.fn.strcharpart(word, 0, cut))
        word = vim.fn.strcharpart(word, cut, n - cut)
      end
      if line == '' then
        line = word
      elseif vim.fn.strdisplaywidth(line) + 1 + vim.fn.strdisplaywidth(word) <= width then
        line = line .. ' ' .. word
      else
        table.insert(out, line)
        line = word
      end
    end
    if line ~= '' then
      table.insert(out, line)
    end
    for i = first, #out do
      out[i] = lead .. out[i]
    end
  end
  return table.concat(out, '\n')
end

--- `virtual_lines.format`: the built-in default text (`code: message`), wrapped to fit.
function M.format(diagnostic)
  local text = diagnostic.message
  if diagnostic.code then
    text = ('%s: %s'):format(diagnostic.code, text)
  end
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local width = text_width(bufnr) - indent_width(bufnr, diagnostic.lnum, diagnostic.col) - CONNECTOR_WIDTH - 1
  return M.wrap(text, math.max(width, M.MIN_WIDTH))
end

--- Redraw diagnostics of the buffers in `wins` so they re-wrap to the new widths.
local function redraw(wins)
  local seen = {}
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if not seen[buf] and #vim.diagnostic.get(buf) > 0 then
        seen[buf] = true
        vim.diagnostic.show(nil, buf)
      end
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom_diagnostic_wrap', { clear = true })
  vim.api.nvim_create_autocmd('WinResized', {
    group = group,
    callback = function()
      -- v:event.windows is unset when fired by hand (`:doautocmd WinResized`): redraw all.
      redraw(vim.v.event.windows or vim.api.nvim_list_wins())
    end,
  })
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      redraw(vim.api.nvim_list_wins())
    end,
  })
end

return M
