-- Startup smoke test: start the config headless, open one file per lazy-loaded filetype, then
-- force-load every remaining plugin, and fail on any error raised along the way.
--
-- Run via `make smoke`. Loaded with `--cmd` so the vim.notify hook is in place before init.lua.
local h = dofile((vim.env.KICKSTART_REPO or vim.fn.getcwd()) .. '/tests/helpers.lua')
h.disable_mason_installs()

-- Messages that are expected in a headless sandbox without the external tools install.sh
-- provides. Keep each one specific and explained; never add a catch-all pattern.
-- (Mason's background installs are switched off up front instead; see helpers.lua.)
local allowed = {}

local function is_allowed(msg)
  for _, pat in ipairs(allowed) do
    if msg:find(pat) then
      return true
    end
  end
  return false
end

local notified = {}
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if level and level >= vim.log.levels.ERROR then
    table.insert(notified, tostring(msg))
  end
  return orig_notify(msg, level, opts)
end

local function check_messages(stage)
  for _, msg in ipairs(notified) do
    if not is_allowed(msg) then
      h.fail(('[%s] vim.notify ERROR: %s'):format(stage, msg))
    end
  end
  notified = {}

  local messages = vim.api.nvim_exec2('messages', { output = true }).output
  for line in vim.gsplit(messages, '\n', { plain = true }) do
    if (line:find '^E%d+:' or line:find 'Error detected while processing' or line:find '^Error') and not is_allowed(line) then
      h.fail(('[%s] message: %s'):format(stage, line))
    end
  end
  vim.cmd 'messages clear'
end

local function run()
  local lazy_config = require 'lazy.core.config'

  for name, plugin in pairs(lazy_config.plugins) do
    if not plugin._.installed then
      h.fail(('plugin %s is not installed (run `make deps`)'):format(name))
    end
  end
  check_messages 'startup'

  h.trigger_very_lazy()
  vim.wait(200)
  check_messages 'VeryLazy'

  h.open_fixtures()
  check_messages 'filetypes'

  -- Plugins that the fixtures above must have loaded via their `ft` trigger.
  for _, name in ipairs { 'nvim-jdtls', 'vimtex', 'venv-selector.nvim', 'nvim-dap-python', 'neotest' } do
    local plugin = lazy_config.plugins[name]
    if not plugin then
      h.fail(('plugin %s is missing from the lazy spec'):format(name))
    elseif not plugin._.loaded then
      h.fail(('plugin %s was not loaded by its filetype trigger'):format(name))
    end
  end

  for _, cmd in ipairs { 'JdtTrustGradleWrapper', 'VenvSelect', 'LazyGit', 'Trouble', 'ConformInfo' } do
    if vim.fn.exists(':' .. cmd) ~= 2 then
      h.fail(('user command :%s is not defined'):format(cmd))
    end
  end

  -- java.lua's config (run by the Sample.java fixture) swaps in the checkbox field picker and
  -- registers the getter/setter and override prompt commands.
  if type(vim.lsp.commands['java.action.generateAccessorsPrompt']) ~= 'function' then
    h.fail 'java.action.generateAccessorsPrompt is not registered in vim.lsp.commands'
  end
  if vim.lsp.commands['java.action.overrideMethodsPrompt'] ~= require('custom.jdtls_picker').override_methods then
    h.fail "java.action.overrideMethodsPrompt is still nvim-jdtls's handler, not custom.jdtls_picker's"
  end
  if require('jdtls.ui').pick_many ~= require('custom.jdtls_picker').pick_many then
    h.fail 'jdtls.ui.pick_many was not replaced by custom.jdtls_picker'
  end

  -- Package inference for Java files under src/ (custom.java_package).
  local java_package = require 'custom.java_package'
  for path, want in pairs {
    ['/r/src/de/tum/cit/aet/pse/Class.java'] = 'de.tum.cit.aet.pse',
    ['/r/src/main/java/com/x/Foo.java'] = 'com.x',
    ['/r/src/test/java/com/x/FooTest.java'] = 'com.x',
    ['/home/src/proj/src/de/x/Foo.java'] = 'de.x',
    ['/r/src/Foo.java'] = false,
    ['/r/src/main/java/Foo.java'] = false,
    ['/r/lib/Foo.java'] = false,
    ['/r/src/my-mod/Foo.java'] = false,
  } do
    local got = java_package.infer(path)
    if (got or false) ~= want then
      h.fail(('java_package.infer(%q) = %s, want %s'):format(path, tostring(got), tostring(want)))
    end
  end
  local tmp = vim.fn.tempname()
  for _, case in ipairs {
    { tmp .. '/src/de/x/A.java', { 'System.out.println(1);' }, { 'package de.x;', '', 'System.out.println(1);' } },
    { tmp .. '/src/de/x/B.java', { '' }, { 'package de.x;', '' } },
    { tmp .. '/src/de/x/C.java', { '', 'class C {}' }, { 'package de.x;', '', 'class C {}' } },
    { tmp .. '/src/de/x/D.java', { 'package a.b;', '', 'class D {}' }, { 'package a.b;', '', 'class D {}' } },
    { tmp .. '/lib/E.java', { 'class E {}' }, { 'class E {}' } },
  } do
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, case[1])
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, case[2])
    java_package.ensure(buf)
    local got = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if not vim.deep_equal(got, case[3]) then
      h.fail(('java_package.ensure on %s gave %s, want %s'):format(vim.fs.basename(case[1]), vim.inspect(got), vim.inspect(case[3])))
    end
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  -- Per-project completion usage ranking (custom.completion_usage).
  local usage = require 'custom.completion_usage'
  for count, want in pairs { [0] = 0, [1] = 3, [3] = 6, [7] = 9, [100] = 12 } do
    if usage.bonus(count) ~= want then
      h.fail(('completion_usage.bonus(%d) = %d, want %d'):format(count, usage.bonus(count), want))
    end
  end
  local real_state_dir = usage.state_dir
  usage.state_dir = tmp .. '/usage-state'
  local function usage_buf(path, ft)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, path)
    -- completion_usage only reads 'filetype'. Skip the FileType autocmd: it would schedule an
    -- LSP start (lua_ls resolves root_dir asynchronously) that runs after the buffer is deleted
    -- below and errors with "Invalid buffer id" from vim.fs.root.
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('noautocmd setlocal filetype=' .. ft)
    end)
    return buf
  end
  local function boosted(buf)
    local item = { label = 'foo(int) : void', filterText = 'foo', kind = 2 }
    usage.boost({ bufnr = buf }, { item })
    return item.score_offset or 0
  end
  vim.fn.mkdir(tmp .. '/projA/.git', 'p')
  vim.fn.mkdir(tmp .. '/projB/.git', 'p')
  local java_buf = usage_buf(tmp .. '/projA/src/A.java', 'java')
  local py_buf = usage_buf(tmp .. '/projB/b.py', 'python')
  local lua_buf = usage_buf(tmp .. '/projA/c.lua', 'lua')
  usage.record(java_buf, { label = 'foo(String s) : void', filterText = 'foo', kind = 2 })
  usage.record(java_buf, { label = 'foo(int) : void', filterText = 'foo', kind = 2 })
  usage.record(lua_buf, { label = 'foo', kind = 2 })
  if boosted(java_buf) ~= 4 then
    h.fail(('completion_usage: java item boosted by %d after 2 uses, want 4'):format(boosted(java_buf)))
  end
  if boosted(py_buf) ~= 0 then
    h.fail 'completion_usage: usage in projA leaked into projB'
  end
  if boosted(lua_buf) ~= 0 then
    h.fail 'completion_usage: lua buffers should not be tracked'
  end
  usage.flush()
  local db_files = vim.fn.glob(usage.state_dir .. '/projA-*.json', false, true)
  local db = #db_files == 1 and vim.json.decode(table.concat(vim.fn.readfile(db_files[1]), '\n')) or {}
  if db['java\t2\tfoo'] ~= 2 or vim.tbl_count(db) ~= 1 then
    h.fail(('completion_usage: projA db is %s, want { "java\\t2\\tfoo": 2 }'):format(vim.inspect(db)))
  end
  for _, buf in ipairs { java_buf, py_buf, lua_buf } do
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  usage.state_dir = real_state_dir

  -- Accepting mid-word swallows a matching tail after the cursor (custom.completion_suffix).
  local suffix = require 'custom.completion_suffix'
  local function edit(s, e, text)
    return { range = { start = { line = 0, character = s }, ['end'] = { line = 0, character = e } }, newText = text }
  end
  -- { name, line, edit, want end column }
  for _, case in ipairs {
    { 'matching tail', 'new UnknownBlueprintException();', edit(4, 20, 'UnknownBlueprintException'), 29 },
    { 'non-matching tail', 'new UnknownFoo();', edit(4, 11, 'UnknownError'), 11 },
    { 'method snippet', 'obj.getFooBar();', edit(4, 9, 'getFooBar(${1})'), 13 },
    { 'nothing after', 'new Unknown', edit(4, 11, 'UnknownError'), 11 },
    { 'tail longer than item', 'new FooBarBaz', edit(4, 5, 'Foo'), 5 },
    { 'case mismatch', 'new UnknownBlueprintexception', edit(4, 20, 'UnknownBlueprintException'), 20 },
    { 'empty newText', 'new Foo', edit(4, 5, ''), 5 },
  } do
    local got = suffix.extend(case[3], case[2]).range['end'].character
    if got ~= case[4] then
      h.fail(('completion_suffix %s: end column %d, want %d'):format(case[1], got, case[4]))
    end
  end
  local multi = edit(4, 5, 'FooBar')
  multi.range['end'].line = 1
  if suffix.extend(multi, 'Bar').range['end'].character ~= 5 then
    h.fail 'completion_suffix: multi-line edit should be left alone'
  end
  -- End to end through blink's own get_from_item (wrapped in init.lua's blink config).
  require('lazy').load { plugins = { 'blink.cmp' } }
  local sfx_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(sfx_buf)
  vim.api.nvim_buf_set_lines(sfx_buf, 0, -1, false, { 'throw new UnknownBlueprintException();' })
  vim.api.nvim_win_set_cursor(0, { 1, 26 })
  local te = require('blink.cmp.lib.text_edits').get_from_item {
    label = 'UnknownBlueprintException',
    cursor_column = 26,
    textEdit = edit(10, 26, 'UnknownBlueprintException'),
  }
  if te.range['end'].character ~= 35 then
    h.fail(('completion_suffix: blink get_from_item end column %d, want 35 (not wrapped?)'):format(te.range['end'].character))
  end
  vim.api.nvim_buf_delete(sfx_buf, { force = true })

  -- Typing on an empty line indents it first (custom.blank_line_indent).
  local bli = require 'custom.blank_line_indent'
  local bli_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bli_buf)
  vim.bo[bli_buf].expandtab, vim.bo[bli_buf].tabstop, vim.bo[bli_buf].shiftwidth = false, 8, 8
  -- { line, desired cols, want prefix }
  for _, case in ipairs {
    { '', 16, '\t\t' },
    { '\t', 16, '\t' },
    { '', 12, '\t    ' },
    { '\t\t', 16, nil },
    { '\t\t\t', 16, nil },
    { '    ', 16, nil },
    { 'x', 16, nil },
    { '', nil, nil },
  } do
    local got = bli.prefix_for(case[1], case[2], bli_buf)
    if got ~= case[3] then
      h.fail(('blank_line_indent.prefix_for(%q, %s) = %q, want %q'):format(case[1], tostring(case[2]), tostring(got), tostring(case[3])))
    end
  end
  vim.bo[bli_buf].expandtab, vim.bo[bli_buf].shiftwidth = true, 4
  if bli.prefix_for('', 8, bli_buf) ~= '        ' then
    h.fail 'blank_line_indent.prefix_for with expandtab should give 8 spaces'
  end
  vim.bo[bli_buf].expandtab, vim.bo[bli_buf].shiftwidth = false, 8

  -- End to end in a Java buffer with treesitter's indentexpr. Filetype set without autocmds so
  -- jdtls doesn't try to attach to this unnamed buffer.
  local java_lines = { 'class Foo {', '\tvoid m() {', '\t\tint x = 1;', '', '\t}', '}' }
  local function blank_line_buf(ft, lines)
    vim.api.nvim_buf_set_lines(bli_buf, 0, -1, false, lines)
    vim.cmd('noautocmd setlocal filetype=' .. ft)
    vim.treesitter.start(bli_buf, ft)
    vim.bo[bli_buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
  blank_line_buf('java', java_lines)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.api.nvim_feedkeys('iObj\27', 'xt', false)
  if vim.fn.getline(4) ~= '\t\tObj' then
    h.fail(('blank_line_indent: typing on the empty line gave %q, want "\\t\\tObj"'):format(vim.fn.getline(4)))
  end

  -- A multi-line LuaSnip snippet expanded there is indented on every line.
  local ls = require 'luasnip'
  if #ls.get_snippets 'java' == 0 then
    require('luasnip.loaders.from_lua').load { paths = { vim.fn.stdpath 'config' .. '/lua/custom/snippets' }, include = { 'java' } }
  end
  local fori
  for _, snippet in ipairs(ls.get_snippets 'java') do
    if snippet.trigger == 'fori' then
      fori = snippet
    end
  end
  blank_line_buf('java', java_lines)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.api.nvim_feedkeys('ifori\27', 'xt', false)
  if not fori then
    h.fail 'blank_line_indent: fori snippet not found'
  else
    vim.api.nvim_win_set_cursor(0, { 4, 6 })
    ls.snip_expand(fori, { clear_region = { from = { 3, 2 }, to = { 3, 6 } } })
    local got = vim.api.nvim_buf_get_lines(bli_buf, 3, 6, false)
    if not (got[1]:match '^\t\tfor %(' and got[2]:match '^\t\t\t' and got[3] == '\t\t}') then
      h.fail('blank_line_indent: fori on the empty line expanded to ' .. vim.inspect(got))
    end
    ls.unlink_current()
    -- Flush the keys LuaSnip queued to select the first placeholder, and leave Select mode.
    vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'xt', false)
  end

  -- Python is excluded: a col-0 line stays at col 0.
  blank_line_buf('python', { 'def f():', '    x = 1', '', '' })
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.api.nvim_feedkeys('iy\27', 'xt', false)
  if vim.fn.getline(3) ~= 'y' then
    h.fail(('blank_line_indent: python line got indented: %q'):format(vim.fn.getline(3)))
  end
  vim.api.nvim_buf_delete(bli_buf, { force = true })

  -- Browser-style tab close/reopen (custom.tabs, <leader>w / <leader>W).
  local tabs = require 'custom.tabs'
  local function tab_file(name, lines)
    local path = tmp .. '/tabs/' .. name
    vim.fn.mkdir(tmp .. '/tabs', 'p')
    vim.fn.writefile(lines or { name .. ' 1', name .. ' 2', name .. ' 3' }, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf()
  end
  local function current_name()
    return vim.fs.basename(vim.api.nvim_buf_get_name(0))
  end
  vim.cmd 'silent! only'
  tab_file 'a.txt'
  tab_file 'b.txt'
  tab_file 'c.txt'
  tab_file 'b.txt'
  vim.api.nvim_win_set_cursor(0, { 2, 1 })
  tab_file 'c.txt' -- MRU now c, b, a; bufferline order is a, b, c
  tabs.close()
  if current_name() ~= 'b.txt' then
    h.fail(('tabs.close from c.txt went to %s, want b.txt'):format(current_name()))
  end
  tabs.close()
  if current_name() ~= 'a.txt' then
    h.fail(('tabs.close from b.txt went to %s, want a.txt'):format(current_name()))
  end
  tabs.reopen()
  if current_name() ~= 'b.txt' or vim.api.nvim_win_get_cursor(0)[1] ~= 2 then
    h.fail(('tabs.reopen gave %s at line %d, want b.txt at line 2'):format(current_name(), vim.api.nvim_win_get_cursor(0)[1]))
  end
  tabs.reopen()
  if current_name() ~= 'c.txt' then
    h.fail(('second tabs.reopen gave %s, want c.txt'):format(current_name()))
  end
  vim.cmd.vsplit()
  tabs.close()
  if #vim.api.nvim_tabpage_list_wins(0) ~= 2 then
    h.fail(('tabs.close in a split left %d windows, want 2'):format(#vim.api.nvim_tabpage_list_wins(0)))
  end
  vim.cmd 'silent! only'
  local dirty = tab_file 'd.txt'
  vim.api.nvim_buf_set_lines(dirty, 0, 1, false, { 'changed' })
  local real_confirm = vim.fn.confirm
  vim.fn.confirm = function()
    return 3 -- Cancel
  end
  tabs.close()
  vim.fn.confirm = real_confirm
  if not vim.api.nvim_buf_is_valid(dirty) or vim.api.nvim_get_current_buf() ~= dirty then
    h.fail 'tabs.close on a modified buffer did not stop when the save prompt was cancelled'
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find(tmp .. '/tabs/', 1, true) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  -- jdtls indentation follows the buffer (custom.jdtls_indent).
  local jdtls_indent = require 'custom.jdtls_indent'
  local ind_buf = vim.api.nvim_create_buf(true, false)
  vim.bo[ind_buf].expandtab = false
  vim.bo[ind_buf].tabstop = 8
  vim.bo[ind_buf].shiftwidth = 0
  local fmt = jdtls_indent.format_settings(ind_buf)
  if fmt.insertSpaces ~= false or fmt.tabSize ~= 8 then
    h.fail(('jdtls_indent: noexpandtab ts=8 sw=0 gave %s'):format(vim.inspect(fmt)))
  end
  vim.bo[ind_buf].expandtab = true
  vim.bo[ind_buf].shiftwidth = 2
  fmt = jdtls_indent.format_settings(ind_buf)
  if fmt.insertSpaces ~= true or fmt.tabSize ~= 2 then
    h.fail(('jdtls_indent: expandtab sw=2 gave %s'):format(vim.inspect(fmt)))
  end
  local notifications = {}
  local fake_client = {
    id = 99,
    name = 'jdtls',
    settings = { java = { imports = { x = 1 } } },
    notify = function(_, method, params)
      table.insert(notifications, { method = method, params = vim.deepcopy(params) })
    end,
  }
  local real_get_clients = vim.lsp.get_clients
  vim.lsp.get_clients = function()
    return { fake_client }
  end
  jdtls_indent.sync(ind_buf)
  jdtls_indent.sync(ind_buf)
  vim.lsp.get_clients = real_get_clients
  local sent_settings = notifications[1] and notifications[1].params.settings or {}
  if
    #notifications ~= 1
    or notifications[1].method ~= 'workspace/didChangeConfiguration'
    or vim.tbl_get(sent_settings, 'java', 'imports', 'x') ~= 1
    or not vim.deep_equal(vim.tbl_get(sent_settings, 'java', 'format'), { insertSpaces = true, tabSize = 2 })
  then
    h.fail(('jdtls_indent.sync sent %s, want one full didChangeConfiguration'):format(vim.inspect(notifications)))
  end
  vim.api.nvim_buf_delete(ind_buf, { force = true })

  -- `new` snippet: declaration at statement start, bare expression inside arguments etc.
  local new_decl, new_expr
  for _, sn in ipairs(dofile((vim.env.KICKSTART_REPO or vim.fn.getcwd()) .. '/lua/custom/snippets/java.lua')) do
    if sn.trigger == 'new' then
      if table.concat(sn.dscr or {}):find 'expression' then
        new_expr = sn
      else
        new_decl = sn
      end
    end
  end
  local snip_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(snip_buf)
  local function new_kind(lines)
    vim.api.nvim_buf_set_lines(snip_buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, #lines[#lines] })
    local prefix = lines[#lines]
    local d, e = new_decl.show_condition(prefix), new_expr.show_condition(prefix)
    return d ~= e and (e and 'expression' or 'statement') or ('both=' .. tostring(d))
  end
  if not (new_decl and new_expr) then
    h.fail 'java snippets: expected two `new` snippets (declaration + expression)'
  else
    for _, case in ipairs {
      { { 'foo(ne' }, 'expression' },
      { { 'foo(a, ne' }, 'expression' },
      { { 'x = ne' }, 'expression' },
      { { 'return ne' }, 'expression' },
      { { 'run(() -> ne' }, 'expression' },
      { { 'var y = cond ? ne' }, 'expression' },
      { { 'method(', '    ne' }, 'expression' },
      { { 'ne' }, 'statement' },
      { { 'int a = 1;', '    ne' }, 'statement' },
      { { 'if (x) ne' }, 'statement' },
      { { 'case A: ne' }, 'statement' },
      { { 'void f() {', '    ne' }, 'statement' },
    } do
      local got = new_kind(case[1])
      if got ~= case[2] then
        h.fail(('java `new` snippet after %s: %s, want %s'):format(vim.inspect(case[1]), got, case[2]))
      end
    end
  end
  vim.api.nvim_buf_delete(snip_buf, { force = true })

  -- Generated declaration snippets (kind + access + mods): unique triggers, right bodies.
  local by_trig = {}
  for _, sn in ipairs(dofile((vim.env.KICKSTART_REPO or vim.fn.getcwd()) .. '/lua/custom/snippets/java.lua')) do
    if by_trig[sn.trigger] and sn.trigger ~= 'new' then
      h.fail('java snippets: duplicate trigger ' .. sn.trigger)
    end
    by_trig[sn.trigger] = sn
  end
  for trig, want in pairs {
    mta = '^protected abstract void name%(.*%);$',
    mps = '^private static void name%(',
    fp = '^private Type name;$',
    ftsf = '^protected static final Type NAME = .*;$',
    clsaei = '^public abstract class .* extends Parent implements Interface {',
  } do
    local sn = by_trig[trig]
    local body = sn and table.concat(sn:get_docstring(), '\n'):gsub('%$%{%d+:([^}]*)%}', '%1'):gsub('%$%d+', '')
    if not body then
      h.fail('java snippets: missing generated trigger ' .. trig)
    elseif not body:match(want) then
      h.fail(('java snippet %s expands to %q, want %s'):format(trig, body, want))
    end
  end
  for _, trig in ipairs { 'mpa', 'prv', 'psf' } do
    if by_trig[trig] then
      h.fail('java snippets: unexpected trigger ' .. trig)
    end
  end

  -- fin / fina: initialise the constructor's remaining fields (`new` or a default value).
  local fin_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(fin_buf)
  vim.cmd 'noautocmd setlocal filetype=java'
  local fin_class = {
    'class Foo {',
    '    private static int COUNT;',
    '    private final List<String> items;',
    '    private Map<String, Integer> counts;',
    '    private int n;',
    '    private boolean done;',
    '    private String label;',
    '    private int[] data;',
    '    private int x;',
    '    private int y = 3;',
    '    private Repo repo;',
    '    public Foo(int x) {',
    '        this.x = x;',
    '        this.label = "a";',
    '        TRIGGER',
    '    }',
    '    void m() {',
    '        TRIGGER',
    '    }',
    '}',
  }
  local function fin_setup(trigger, line)
    local lines = vim.deepcopy(fin_class)
    lines[15] = lines[15]:gsub('TRIGGER', trigger)
    lines[18] = lines[18]:gsub('TRIGGER', trigger)
    vim.api.nvim_buf_set_lines(fin_buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { line, #lines[line] })
    return lines[line]
  end
  for _, case in ipairs {
    { 'fin', 15, true },
    { 'fina', 15, true },
    { 'fin', 18, false }, -- in a method, not a constructor
    { 'foo(fin', 15, false }, -- expression position
  } do
    local trig = case[1]:match '%w+$'
    if not by_trig[trig] then
      h.fail('java snippets: missing trigger ' .. trig)
    elseif by_trig[trig].show_condition(fin_setup(case[1], case[2])) ~= case[3] then
      h.fail(('java %s snippet listed=%s on %q, want %s'):format(trig, not case[3], case[1], case[3]))
    end
  end
  local function fin_expand(trig)
    fin_setup('', 15)
    require('luasnip').snip_expand(by_trig[trig], { pos = { 14, 8 } })
    require('luasnip').unlink_current()
    return vim.api.nvim_buf_get_lines(fin_buf, 14, -1, false)
  end
  local got = fin_expand 'fina'
  local want = {
    '        this.items = new ArrayList<>();',
    '        this.counts = new HashMap<>();',
    '        this.n = 0;',
    '        this.done = false;',
    '        this.data = new int[0];',
    '        this.repo = new Repo();',
    '    }',
  }
  if not vim.deep_equal(vim.list_slice(got, 1, #want), want) then
    h.fail(('java fina expanded to %s, want %s'):format(vim.inspect(got), vim.inspect(want)))
  end
  got = fin_expand('fin')[1]
  if got ~= '        this.items = new ArrayList<>();' then
    h.fail(('java fin expanded to %q'):format(got))
  end
  -- Nothing left to initialise once fina has run: neither snippet is listed.
  fin_setup('', 15)
  vim.api.nvim_buf_set_lines(fin_buf, 14, 15, false, vim.list_extend(vim.list_slice(want, 1, 6), { '        fin' }))
  vim.api.nvim_win_set_cursor(0, { 21, 11 })
  if by_trig.fin.show_condition '        fin' then
    h.fail 'java fin snippet listed although every field is initialised'
  end
  vim.api.nvim_buf_delete(fin_buf, { force = true })

  -- /* */ block comments for gc / gcc in Java (custom.block_comment). noautocmd keeps jdtls from
  -- trying to attach to the scratch buffer; the maps are attached by hand instead.
  local bc_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bc_buf)
  vim.cmd 'noautocmd setlocal filetype=java'
  require('custom.block_comment').attach(bc_buf)
  local function comment_case(name, lines, cursor, keys, want)
    vim.api.nvim_buf_set_lines(bc_buf, 0, -1, false, lines)
    vim.bo[bc_buf].undolevels = vim.bo[bc_buf].undolevels -- undo break, so `u` stops here
    vim.api.nvim_win_set_cursor(0, { cursor, 0 })
    vim.cmd('normal ' .. keys)
    local got = vim.api.nvim_buf_get_lines(bc_buf, 0, -1, false)
    if not vim.deep_equal(got, want) then
      h.fail(('block_comment %s: `%s` gave %s, want %s'):format(name, keys, vim.inspect(got), vim.inspect(want)))
    end
  end
  local code = { 'class A {', '    int a = 1;', '', '    int b = 2;', '}' }
  local wrapped = { 'class A {', '    /*', '    int a = 1;', '', '    int b = 2;', '    */', '}' }
  comment_case('wrap', code, 2, 'Vjjgc', wrapped)
  comment_case('wrap via motion', code, 2, 'gc2j', wrapped)
  comment_case('unwrap with gcc', wrapped, 4, 'gcc', code)
  comment_case('unwrap with gcgc', wrapped, 3, 'gcgc', code)
  comment_case('unwrap from the */ line', wrapped, 6, 'gcc', code)
  comment_case('dgc deletes the block', wrapped, 3, 'dgc', { 'class A {', '}' })
  comment_case('single line uses //', code, 2, 'gcc', { 'class A {', '    // int a = 1;', '', '    int b = 2;', '}' })
  comment_case('3gcc wraps', code, 2, '3gcc', wrapped)
  comment_case('// lines uncomment', { '    // int a = 1;', '    // int b = 2;' }, 1, 'Vjgc', { '    int a = 1;', '    int b = 2;' })
  comment_case('inline delimiters', { '    /* int a = 1;', '    int b = 2; */' }, 1, 'gcc', { '    int a = 1;', '    int b = 2;' })
  comment_case('one-line block', { '    /* int a = 1; */' }, 1, 'gcc', { '    int a = 1;' })
  comment_case(
    'decorated block',
    { '    /*', '     * int a = 1;', '     *', '     * int b = 2;', '     */' },
    2,
    'gcc',
    { '    int a = 1;', '', '    int b = 2;' }
  )
  comment_case('javadoc is left to the built-in', { '    /** Doc. */' }, 1, 'gcc', { '    // /** Doc. */' })
  comment_case('trailing comment is left to the built-in', { '    f(); /* x */' }, 1, 'gcc', { '    // f(); /* x */' })
  comment_case('range containing */ falls back to //', { 'f(); /* x */', 'g();' }, 1, 'Vjgc', { '// f(); /* x */', '// g();' })
  comment_case('one undo step', code, 2, 'Vjjgcu', code)
  comment_case('dot repeats a wrap', { 'a();', 'b();', '', 'c();', 'd();' }, 1, 'Vjgc5j.', { '/*', 'a();', 'b();', '*/', '', '/*', 'c();', 'd();', '*/' })
  vim.api.nvim_buf_delete(bc_buf, { force = true })

  -- DevOps filetype detection (custom.filetypes) and the LSP/lint setup that depends on it.
  for path, want in pairs {
    ['/r/compose.yaml'] = 'yaml.docker-compose',
    ['/r/docker-compose.yml'] = 'yaml.docker-compose',
    ['/r/docker-compose.override.yml'] = 'yaml.docker-compose',
    ['/r/compose.prod.yaml'] = 'yaml.docker-compose',
    ['/r/.github/workflows/ci.yml'] = 'yaml.github',
    ['/r/site.nginx'] = 'nginx',
    ['/r/nginx/templates/default.conf.template'] = 'nginx',
    ['/r/nginx/sites-enabled/app'] = 'nginx',
    ['/etc/apache2/sites-available/app.conf'] = 'apache',
    ['/r/config.yaml'] = 'yaml',
    ['/r/mycompose.yaml'] = 'yaml',
  } do
    local got = vim.filetype.match { filename = path }
    if got ~= want then
      h.fail(('filetype of %s is %s, want %s'):format(path, tostring(got), want))
    end
  end
  local yamlls = vim.lsp.config.yamlls or {}
  if not vim.tbl_contains(yamlls.filetypes or {}, 'yaml.github') then
    h.fail(('yamlls filetypes %s lack yaml.github'):format(vim.inspect(yamlls.filetypes)))
  end
  if next(vim.tbl_get(yamlls, 'settings', 'yaml', 'schemas') or {}) == nil then
    h.fail 'yamlls has no SchemaStore schemas'
  end
  if #(vim.tbl_get(vim.lsp.config.jsonls or {}, 'settings', 'json', 'schemas') or {}) == 0 then
    h.fail 'jsonls has no SchemaStore schemas'
  end
  if not vim.lsp.is_enabled 'nginx_language_server' then
    h.fail 'nginx_language_server is not enabled (it is not Mason-installed, so init.lua must enable it)'
  end
  if not vim.deep_equal(require('lint').linters_by_ft['yaml.github'], { 'actionlint' }) then
    h.fail 'nvim-lint does not run actionlint on yaml.github'
  end

  -- Everything still lazy (cmd/keys-triggered: trouble, lazygit, toggleterm, ...) gets its
  -- config run now, so a broken config can't hide behind a trigger nobody exercised.
  local pending = {}
  for name, plugin in pairs(lazy_config.plugins) do
    if plugin._.installed and not plugin._.loaded then
      table.insert(pending, name)
    end
  end
  if #pending > 0 then
    require('lazy').load { plugins = pending }
    vim.wait(200)
  end
  check_messages 'force-load'
  return ('startup clean, %d plugins loaded'):format(vim.tbl_count(lazy_config.plugins))
end

h.run_on_vim_enter(run)
