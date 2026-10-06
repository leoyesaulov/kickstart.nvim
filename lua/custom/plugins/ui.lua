-- IDE chrome: buffer tabs, an aggregated problems panel, an integrated terminal, and a git panel.
-- Keymap namespaces checked against existing bindings before picking these (see bindings.md):
-- `<leader>b`/`<leader>B` are taken by debug.lua's breakpoint toggles, so bufferline uses bare
-- `<Tab>`/`<S-Tab>` (normal mode only — blink.cmp's Tab/S-Tab mappings are insert-mode only,
-- so there's no conflict) instead of a `<leader>b*` prefix.
return {
  { -- Buffer tabs, like an IDE's open-editors bar
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    keys = {
      { '<Tab>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer tab' },
      { '<S-Tab>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Previous buffer tab' },
    },
    opts = {
      options = {
        diagnostics = 'nvim_lsp',
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },
  { -- Aggregated diagnostics/quickfix panel — IDE "Problems" panel analog
    'folke/trouble.nvim',
    dependencies = 'nvim-tree/nvim-web-devicons',
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = '[X] Diagnostics (Trouble)' },
      { '<leader>xw', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = '[X] Buffer diagnostics (Trouble)' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = '[X] Quickfix (Trouble)' },
    },
    opts = {},
  },
  { -- Integrated terminal, multiple instances, like an IDE's embedded terminal
    'akinsho/toggleterm.nvim',
    version = '*',
    keys = {
      { '<leader>tt', '<cmd>ToggleTerm<cr>', desc = '[T]oggle [T]erminal' },
    },
    opts = {
      direction = 'float',
    },
  },
  { -- Floating lazygit panel — IDE-like git UI without reinventing fugitive
    'kdheepak/lazygit.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    cmd = { 'LazyGit' },
    keys = {
      { '<leader>gg', '<cmd>LazyGit<cr>', desc = '[G]it [G]ui (lazygit)' },
    },
  },
}
