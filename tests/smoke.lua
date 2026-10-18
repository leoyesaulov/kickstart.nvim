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
