-- Python: virtualenv/interpreter picker + debugpy wiring into the shared nvim-dap base from
-- lua/kickstart/plugins/debug.lua. Ruff (lint/format) and pyright (types) are configured as
-- ordinary LSP servers in init.lua; neotest-python lives in lua/custom/plugins/testing.lua.
return {
  { -- Pick a venv/poetry/conda/pipenv interpreter and point pyright at it
    'linux-cultist/venv-selector.nvim',
    dependencies = { 'neovim/nvim-lspconfig', 'nvim-telescope/telescope.nvim', 'mfussenegger/nvim-dap-python' },
    cmd = 'VenvSelect',
    ft = 'python',
    keys = {
      { '<leader>cv', '<cmd>VenvSelect<cr>', desc = '[C]ode [V]env select' },
    },
    opts = {}, -- defaults auto-detect .venv/venv/poetry/conda under cwd; see plugin README for overrides
  },
  { -- debugpy, resolved from Mason's install, hooked into the shared dap/dap-ui base
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      local ok, debugpy_pkg = pcall(require('mason-registry').get_package, 'debugpy')
      if ok and debugpy_pkg:is_installed() then
        require('dap-python').setup(debugpy_pkg:get_install_path() .. '/venv/bin/python')
      end
    end,
  },
}
