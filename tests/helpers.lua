-- Shared bits for the tests/*.lua scripts. Loaded with dofile() because tests/
-- isn't on the runtimepath. Both scripts run inside tests/env.sh's sandbox.
local M = {}

M.repo = vim.env.KICKSTART_REPO or vim.fn.getcwd()

-- Replace module `name`'s function `fn` with `wrap(original)` the first time the module is
-- required. Must run before init.lua, i.e. from `nvim --cmd`.
local function wrap_module_fn(name, fn, wrap)
  package.preload[name] = function()
    package.preload[name] = nil
    -- Resolve through the remaining searchers (lazy.nvim's / runtimepath), skipping preload.
    for i = 2, #package.loaders do
      local loader = package.loaders[i](name)
      if type(loader) == 'function' then
        local mod = loader(name)
        mod[fn] = wrap(mod[fn])
        return mod
      end
    end
    error('module ' .. name .. ' not found')
  end
end

-- Merge `override` over whatever options init.lua passes to `name`.setup().
local function override_setup(name, override)
  wrap_module_fn(name, 'setup', function(setup)
    return function(opts)
      return setup(vim.tbl_extend('force', opts or {}, override))
    end
  end)
end

-- Mason installs (LSP servers, formatters, debug adapters) are network downloads that race the
-- test's exit and fail nondeterministically; they aren't what's under test. Keep init.lua's
-- setup calls but stop them from installing anything.
function M.disable_mason_installs()
  override_setup('mason-tool-installer', { run_on_start = false })
  override_setup('mason-nvim-dap', { ensure_installed = {}, automatic_installation = false })
end

-- init.lua's treesitter config starts an async install of its ensure_installed parsers. Record
-- the requested languages and returned tasks so tests/deps.lua can wait for them instead of
-- racing the exit.
M.parser_installs = {}
function M.track_parser_installs()
  wrap_module_fn('nvim-treesitter', 'install', function(install)
    return function(langs, ...)
      local task = install(langs, ...)
      table.insert(M.parser_installs, { langs = langs, task = task })
      return task
    end
  end)
end

local failures = {}

function M.fail(msg)
  table.insert(failures, msg)
end

-- Print every failure and exit nonzero, or print `ok_msg` and exit 0.
function M.finish(ok_msg)
  if #failures > 0 then
    io.stderr:write(('\nFAIL  %d problem(s):\n'):format(#failures))
    for _, f in ipairs(failures) do
      io.stderr:write('  - ' .. f:gsub('\n', '\n    ') .. '\n')
    end
    vim.cmd 'cquit 1'
  else
    io.stdout:write('\nOK    ' .. ok_msg .. '\n')
    vim.cmd 'qall!'
  end
end

-- Headless nvim never fires UIEnter, so lazy.nvim never emits VeryLazy on its own.
function M.trigger_very_lazy()
  vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
end

-- One fixture per lazy-loaded filetype. `needs` = executable required to open it at all
-- (jupytext.nvim shells out to `jupytext` to convert the notebook).
M.fixtures = {
  { file = 'sample.lua' },
  { file = 'sample.py' },
  { file = 'Sample.java' },
  { file = 'sample.tex' },
  { file = 'sample.ipynb', needs = 'jupytext' },
}

-- :edit every fixture (each in its own buffer) and return { [fixture.file] = bufnr }.
-- Fixtures whose `needs` executable is missing are skipped with a note.
function M.open_fixtures()
  local bufs = {}
  for _, fx in ipairs(M.fixtures) do
    if fx.needs and vim.fn.executable(fx.needs) == 0 then
      io.stdout:write(('\nSKIP  %s (%s not on PATH)\n'):format(fx.file, fx.needs))
    else
      local path = M.repo .. '/tests/fixtures/' .. fx.file
      local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
      if not ok then
        M.fail(('opening %s raised: %s'):format(fx.file, err))
      end
      bufs[fx.file] = vim.api.nvim_get_current_buf()
    end
  end
  -- Let scheduled FileType/BufEnter work (lazy loads, deferred plugin setup) run.
  vim.wait(500)
  return bufs
end

-- Run `fn` once startup is done; it returns the OK message. A Lua error in the test itself
-- counts as a failure, and a watchdog kills a run that hangs (e.g. on a blocking prompt).
function M.run_on_vim_enter(fn, timeout_s)
  timeout_s = timeout_s or 180
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = vim.schedule_wrap(function()
      local ok, res = xpcall(fn, debug.traceback)
      if not ok then
        M.fail('test script error: ' .. tostring(res))
      end
      M.finish(ok and res or 'unused')
    end),
  })
  vim.defer_fn(function()
    io.stderr:write(('\nFAIL  timed out after %ds\n'):format(timeout_s))
    vim.cmd 'cquit 2'
  end, timeout_s * 1000)
end

return M
