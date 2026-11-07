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
    vim.bo[buf].filetype = ft
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
