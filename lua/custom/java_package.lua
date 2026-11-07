-- Insert a `package …;` declaration into Java buffers that lack one, inferred from the file's
-- location under src/. Hooked up from a FileType autocmd in lua/custom/plugins/java.lua.
--
--   repo/src/de/tum/cit/aet/pse/Foo.java   -> package de.tum.cit.aet.pse;
--   app/src/main/java/com/x/Foo.java        -> package com.x;   (Maven/Gradle <set>/java stripped)
--
-- Uses the nearest (last) src/ in the path, so a src/ higher up (e.g. ~/src/...) doesn't win.
-- Does nothing without a src/, for the default package (file directly in src/), or when a path
-- segment isn't a valid Java identifier.
local M = {}

local function is_identifier(segment)
  return segment:match '^[%a_$][%w_$]*$' ~= nil
end

--- Package name for a .java file path, or nil if none can be inferred.
---@param path string
---@return string|nil
function M.infer(path)
  local parts = vim.split(vim.fs.normalize(path), '/', { plain = true, trimempty = true })
  table.remove(parts) -- file name

  local src
  for idx = #parts, 1, -1 do
    if parts[idx] == 'src' then
      src = idx
      break
    end
  end
  if not src then
    return nil
  end

  local rest = vim.list_slice(parts, src + 1)
  if #rest >= 2 and rest[2] == 'java' then
    rest = vim.list_slice(rest, 3)
  end
  if #rest == 0 then
    return nil
  end
  for _, segment in ipairs(rest) do
    if not is_identifier(segment) then
      return nil
    end
  end
  return table.concat(rest, '.')
end

--- Insert the inferred package declaration at the top of `buf` unless it already has one.
--- Only prepends lines; the rest of the buffer is left as is.
---@param buf integer
function M.ensure(buf)
  if vim.bo[buf].buftype ~= '' or not vim.bo[buf].modifiable then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if not name:match '%.java$' then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match '^%s*package%s+[%w_.$]+%s*;' then
      return
    end
  end

  local pkg = M.infer(name)
  if not pkg then
    return
  end

  local was_empty = #lines == 1 and lines[1] == ''
  -- Exactly one blank line after the declaration: reuse a leading blank line if there is one.
  local insert = lines[1] == '' and { 'package ' .. pkg .. ';' } or { 'package ' .. pkg .. ';', '' }
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, insert)
  -- FileType runs inside the file read, and Neovim resets 'modified' once the read finishes,
  -- which would let :q drop the inserted line silently. Mark it unsaved after that.
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.bo[buf].modified = true
    end
  end)

  if was_empty and vim.api.nvim_get_current_buf() == buf then
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
  end
end

return M
