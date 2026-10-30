-- <leader>r: run the current file in a floating terminal, whatever its language.
--
-- Each runner gets the file's absolute path and calls `done(cmd, cwd)` with the argv to run, or
-- returns without calling it after notifying why it can't. Runners are async because Java has to
-- ask jdtls for the classpath. To support another language, add a `runners[<filetype>]` entry.
local runners = {}

function runners.python(file, done)
  local python
  local ok, venv_selector = pcall(require, 'venv-selector')
  if ok then
    python = venv_selector.python()
  end
  if not python and vim.env.VIRTUAL_ENV then
    python = vim.env.VIRTUAL_ENV .. '/bin/python'
  end
  if not python then
    local root = vim.fs.root(0, { 'pyproject.toml', '.git' })
    if root and vim.fn.executable(root .. '/.venv/bin/python') == 1 then
      python = root .. '/.venv/bin/python'
    end
  end
  done({ python or 'python3', file }, vim.fs.dirname(file))
end

function runners.java(file, done)
  local client = vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' })[1]
  if not client then
    -- Loose file (no project root, so no jdtls): single-file source launch, Java 11+.
    local java = require('custom.java_home').find_java()
    if not java then
      vim.notify('run: no JDK found (macOS: brew install openjdk, or set JAVA_HOME)', vim.log.levels.WARN)
      return
    end
    done({ java, file }, vim.fs.dirname(file))
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local pkg
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    pkg = line:match '^%s*package%s+([%w_.]+)%s*;'
    if pkg then
      break
    end
  end
  local class = vim.fn.fnamemodify(file, ':t:r')
  local main_class = pkg and pkg .. '.' .. class or class

  -- Not jdtls.compile(): its callback only fires on errors. 1 = SUCCEED, 2 = WITHERROR (errors
  -- somewhere in the workspace; this file's classes are still emitted unless it has errors itself).
  client:request('java/buildWorkspace', false, function(err, status)
    if err or (status ~= 1 and status ~= 2) then
      vim.notify('run: jdtls build failed' .. (err and (': ' .. err.message) or ''), vim.log.levels.ERROR)
      return
    end
    if #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }) > 0 then
      vim.notify('run: ' .. class .. ' has compile errors', vim.log.levels.ERROR)
      return
    end
    -- Same discovery the <F5> picker uses; it carries the resolved classpath and the JDK jdtls
    -- picked for the project.
    vim.api.nvim_buf_call(bufnr, function()
      require('jdtls.dap').fetch_main_configs(nil, function(configs)
        for _, config in ipairs(configs) do
          if config.mainClass == main_class then
            -- javaExec is nil when jdtls can't name the project's JDK; a bare `java` may be the macOS stub.
            local cmd = { config.javaExec or require('custom.java_home').find_java() or 'java' }
            if config.vmArgs then
              table.insert(cmd, config.vmArgs)
            end
            vim.list_extend(cmd, { '-cp', table.concat(config.classPaths, ':'), main_class })
            done(cmd, config.cwd)
            return
          end
        end
        vim.notify('run: no main method in ' .. main_class, vim.log.levels.WARN)
      end)
    end)
  end, bufnr)
end

-- The terminal of the previous run, shut down when the next one starts so runs don't pile up.
local last

local function run()
  local ft = vim.bo.filetype
  local runner = runners[ft]
  if not runner then
    vim.notify('run: no runner for ' .. (ft == '' and 'this buffer' or ft), vim.log.levels.WARN)
    return
  end
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('run: save the buffer to a file first', vim.log.levels.WARN)
    return
  end
  vim.cmd 'update'
  runner(file, function(cmd, cwd)
    vim.schedule(function()
      if last then
        last:shutdown()
      end
      last = require('toggleterm.terminal').Terminal:new {
        cmd = table.concat(vim.tbl_map(vim.fn.shellescape, cmd), ' '),
        dir = cwd,
        direction = 'float',
        close_on_exit = false,
      }
      last:open()
    end)
  end)
end

return {
  'akinsho/toggleterm.nvim',
  keys = {
    { '<leader>r', run, desc = '[R]un current file' },
  },
}
