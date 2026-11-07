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
