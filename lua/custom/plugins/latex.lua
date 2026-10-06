-- LaTeX via vimtex: compilation through latexmk, forward/backward PDF sync, folding.
-- Needs a TeX distribution providing `latexmk` and a PDF viewer for forward-search — both
-- installed by install.sh's `ensure_tex_distribution`/`ensure_pdf_viewer` (Linux: zathura).
-- texlab (completion/diagnostics) is configured as an ordinary LSP server in init.lua.
--
-- vimtex intentionally sets its g: vars in `init` (not `config`) so they're in place before
-- vimtex's own ftplugin runs on the first .tex buffer — this is vimtex's documented way to work
-- with lazy-loading, rather than disabling lazy-loading altogether.
return {
  'lervag/vimtex',
  ft = 'tex',
  init = function()
    vim.g.vimtex_view_method = vim.fn.has 'mac' == 1 and 'skim' or 'zathura'
    vim.g.vimtex_quickfix_mode = 0
  end,
}
