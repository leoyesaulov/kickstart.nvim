-- IntelliJ-style checkbox picker for jdtls's "Generate ..." source actions (constructors,
-- getters/setters, toString, equals/hashCode, override/delegate methods). Lives outside
-- lua/custom/plugins/ so lazy doesn't import it as a plugin spec; wired up in plugins/java.lua.
local M = {}

-- Saved before plugins/java.lua swaps in M.pick_many, for callers outside a coroutine.
local upstream_pick_many = require('jdtls.ui').pick_many

local footer = ' <Space> toggle · a all · <CR> generate · q cancel '

--- Floating checkbox list. Calls on_done(selected) on <CR>; cancelling (q/<Esc>/leaving the
--- window) calls nothing.
function M.pick_many_async(items, prompt, label_fn, opts, on_done)
  label_fn = label_fn or tostring
  opts = opts or {}
  local checked = {}
  for i, item in ipairs(items) do
    checked[i] = opts.is_selected and opts.is_selected(item) or false
  end
  local labels = vim.tbl_map(label_fn, items)
  -- nvim-jdtls prompts end in ': ' or '?'; the float title doesn't need either.
  local title = ' ' .. prompt:gsub('[%s:?]+$', '') .. ' '

  local width = vim.fn.strdisplaywidth(footer)
  for _, label in ipairs(labels) do
    width = math.max(width, vim.fn.strdisplaywidth(label) + 5)
  end
  width = math.min(math.max(width, vim.fn.strdisplaywidth(title)), vim.o.columns - 4)
  local height = math.min(#items, vim.o.lines - 6)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
    footer = footer,
    footer_pos = 'center',
  })
  vim.wo[win].cursorline = true

  local function render()
    local lines = {}
    for i, label in ipairs(labels) do
      lines[i] = (checked[i] and '[x] ' or '[ ] ') .. label
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end
  render()

  local done = false
  local function finish(confirmed)
    if done then
      return
    end
    done = true
    pcall(vim.api.nvim_win_close, win, true)
    if confirmed then
      local selected = {}
      for i, item in ipairs(items) do
        if checked[i] then
          table.insert(selected, item)
        end
      end
      on_done(selected)
    end
  end

  local function map(keys, fn)
    for _, key in ipairs(keys) do
      vim.keymap.set('n', key, fn, { buffer = buf, nowait = true })
    end
  end
  map({ '<Space>', '<Tab>' }, function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    checked[row] = not checked[row]
    render()
    vim.api.nvim_win_set_cursor(win, { math.min(row + 1, #items), 0 })
  end)
  map({ 'a' }, function()
    local all = not vim.iter(checked):all(function(c)
      return c
    end)
    for i in ipairs(items) do
      checked[i] = all
    end
    render()
  end)
  map({ '<CR>' }, function()
    finish(true)
  end)
  map({ 'q', '<Esc>' }, function()
    finish(false)
  end)
  -- Closing a window from inside WinLeave errors, so defer it.
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        finish(false)
      end)
    end,
  })
end

--- Drop-in for jdtls.ui.pick_many, which nvim-jdtls calls synchronously from inside its
--- jdtls.async coroutines. Yields until <CR>; on cancel the coroutine is never resumed, so the
--- handler is dropped before it sends its generate request (upstream's prompt can't abort).
function M.pick_many(items, prompt, label_fn, opts)
  if not items or #items == 0 then
    return {}
  end
  local co, is_main = coroutine.running()
  if not co or is_main then
    return upstream_pick_many(items, prompt, label_fn, opts)
  end
  M.pick_many_async(items, prompt, label_fn, opts, function(selected)
    vim.schedule(function()
      coroutine.resume(co, selected)
    end)
  end)
  return coroutine.yield()
end

-- AccessorKind arrives as its ordinal: GETTER, SETTER, BOTH.
local accessor_prompts = {
  [0] = 'Generate getters for',
  [1] = 'Generate setters for',
  [2] = 'Generate getters and setters for',
}

--- Handler for jdtls's `java.action.generateAccessorsPrompt` client command, which nvim-jdtls
--- doesn't implement. jdtls only sends it when advancedGenerateAccessorsSupport is advertised.
function M.generate_accessors(command, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local params = command.arguments and command.arguments[1]
  if not client or not params then
    return
  end
  client:request('java/resolveUnimplementedAccessors', params, function(err, fields)
    if err then
      vim.notify('jdtls: resolveUnimplementedAccessors failed: ' .. err.message, vim.log.levels.ERROR)
      return
    elseif not fields or #fields == 0 then
      vim.notify('jdtls: every field already has its getters/setters', vim.log.levels.INFO)
      return
    end
    local prompt = accessor_prompts[params.kind] or accessor_prompts[2]
    M.pick_many_async(fields, prompt, function(f)
      return ('%s: %s%s'):format(f.fieldName, f.typeName, f.isStatic and ' (static)' or '')
    end, {
      is_selected = function()
        return true
      end,
    }, function(selected)
      if #selected == 0 then
        return
      end
      client:request('java/generateAccessors', { context = params, accessors = selected }, function(err2, edit)
        if err2 then
          vim.notify('jdtls: generateAccessors failed: ' .. err2.message, vim.log.levels.ERROR)
        elseif edit then
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end, ctx.bufnr)
    end)
  end, ctx.bufnr)
end

--- Replaces nvim-jdtls's `java.action.overrideMethodsPrompt` handler, so abstract methods from
--- interfaces/parent classes come first and start checked (IntelliJ's Implement Methods).
--- ctx.params is the textDocument/codeAction request the action came from.
function M.override_methods(_, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client or not ctx.params then
    return
  end
  client:request('java/listOverridableMethods', ctx.params, function(err, result)
    if err then
      vim.notify('jdtls: listOverridableMethods failed: ' .. err.message, vim.log.levels.ERROR)
      return
    elseif not result or not result.methods or #result.methods == 0 then
      vim.notify('jdtls: no methods to override', vim.log.levels.INFO)
      return
    end
    -- Abstract first; table.sort isn't stable, so split instead.
    local methods = vim.list_extend(
      vim.tbl_filter(function(m)
        return m.unimplemented
      end, result.methods),
      vim.tbl_filter(function(m)
        return not m.unimplemented
      end, result.methods)
    )
    M.pick_many_async(methods, 'Implement / override methods', function(m)
      return ('%s(%s) — %s%s'):format(m.name, table.concat(m.parameters, ', '), m.declaringClass, m.unimplemented and ' (abstract)' or '')
    end, {
      is_selected = function(m)
        return m.unimplemented
      end,
    }, function(selected)
      if #selected == 0 then
        return
      end
      client:request('java/addOverridableMethods', { context = ctx.params, overridableMethods = selected }, function(err2, edit)
        if err2 then
          vim.notify('jdtls: addOverridableMethods failed: ' .. err2.message, vim.log.levels.ERROR)
        elseif edit then
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end, ctx.bufnr)
    end)
  end, ctx.bufnr)
end

--- <leader>ji: the override picker for the class under the cursor, without the source-action menu.
function M.implement_methods()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ name = 'jdtls', bufnr = bufnr })[1]
  if not client then
    vim.notify('jdtls: not attached to this buffer', vim.log.levels.WARN)
    return
  end
  local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
  params.context = { diagnostics = {} }
  M.override_methods(nil, { bufnr = bufnr, client_id = client.id, params = params })
end

return M
