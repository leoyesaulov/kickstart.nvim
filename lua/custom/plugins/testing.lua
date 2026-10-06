-- In-editor test runner: run/debug a single test under the cursor, like PyCharm's gutter icons.
-- Scope: Python only (neotest-python/pytest), per explicit decision — Java/C neotest adapters
-- are unmaintained/weak. Java/C testing goes through the DAP debugger directly (breakpoint in a
-- test method, <F5>) or a terminal (mvn test / gradle test / make test) via toggleterm.
return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/neotest-python',
  },
  ft = 'python',
  keys = {
    {
      '<leader>tr',
      function()
        require('neotest').run.run()
      end,
      desc = '[T]est [R]un nearest',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = '[T]est run [F]ile',
    },
    {
      '<leader>td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = '[T]est [D]ebug nearest',
    },
    {
      '<leader>ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = '[T]est [S]ummary panel',
    },
    {
      '<leader>to',
      function()
        require('neotest').output.open { enter = true }
      end,
      desc = '[T]est [O]utput',
    },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-python' {
          dap = { justMyCode = false },
        },
      },
    }
  end,
}
