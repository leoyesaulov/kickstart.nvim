-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  { -- In-buffer, Treesitter-powered markdown preview (no browser/Node required)
    'OXY2DEV/markview.nvim',
    lazy = false, -- load immediately so markdown buffers render on open
    dependencies = {
      -- nvim-treesitter is already configured (with branch/opts) in init.lua;
      -- redeclaring it bare here would clobber that spec during merge.
      'nvim-tree/nvim-web-devicons',
    },
  },
}
