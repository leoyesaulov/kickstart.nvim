-- blink.cmp: accepting in the middle of a word swallows the rest of the word when it's exactly
-- the tail of what gets inserted, instead of duplicating it:
--   new UnknownBlueprint|Exception()  + UnknownBlueprintException  ->  new UnknownBlueprintException()
-- Text after the cursor that doesn't match is left alone (unlike keyword.range = 'full'):
--   new Unknown|Foo()                 + UnknownError               ->  new UnknownErrorFoo()
--
-- Done by wrapping blink's text_edits.get_from_item, which builds the final edit for accept, the
-- auto_insert preview (its undo restores the swallowed text) and ghost text. Wired up in init.lua.
--
-- Limitation: blink records dot-repeat as "N backspaces + text", so `.` after an accept that
-- swallowed a tail deletes that many extra chars before the cursor (same as blink's 'full' mode).
local M = {}

--- Extend a single-line edit over the identifier right after it, if the inserted text's leading
--- identifier ends with exactly that identifier. Mutates and returns `text_edit`.
--- @param text_edit lsp.TextEdit utf-8, 0-indexed
--- @param line string the line the edit ends on
--- @return lsp.TextEdit
function M.extend(text_edit, line)
  local range = text_edit.range
  if not range or range.start.line ~= range['end'].line or type(text_edit.newText) ~= 'string' then
    return text_edit
  end

  local suffix = line:sub(range['end'].character + 1):match '^[%w_]+'
  local ident = text_edit.newText:match '^[%w_]+'
  if suffix and ident and #suffix <= #ident and ident:sub(-#suffix) == suffix then
    range['end'].character = range['end'].character + #suffix
  end
  return text_edit
end

function M.setup()
  local text_edits = require 'blink.cmp.lib.text_edits'
  if text_edits._suffix_wrapped then
    return
  end
  local context = require 'blink.cmp.completion.trigger.context'
  local get_from_item = text_edits.get_from_item

  text_edits.get_from_item = function(item)
    local text_edit = get_from_item(item)
    if context.get_mode() ~= 'default' then
      return text_edit
    end
    local end_line = text_edit.range and text_edit.range['end'].line
    if end_line == nil then
      return text_edit
    end
    local line = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ''
    return M.extend(text_edit, line)
  end
  text_edits._suffix_wrapped = true
end

return M
