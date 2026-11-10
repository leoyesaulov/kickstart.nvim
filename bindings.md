# Keybindings Reference

Flat, sorted-by-key reference of every binding in this config. For a narrative, topic-grouped
walkthrough see [cheatsheet.md](cheatsheet.md).

Leader: `<Space>`. Status `Active` = loaded right now; `Disabled` = defined in a plugin file
whose `require(...)`/import is commented out. As of this revision every plugin file under
`lua/kickstart/plugins/` is enabled (see `init.lua`'s `lazy.setup{}` call), so nothing in this
table is currently `Disabled`.

| Key | Mode | Action | Source | Status |
|---|---|---|---|---|
| `<Esc>` | Normal | Clear search highlight | init.lua:174 | Active |
| `<Esc><Esc>` | Terminal | Exit terminal mode to Normal (fallback `<C-\><C-n>`) | init.lua:185 | Active |
| `<leader><leader>` | Normal | Find existing buffers | init.lua:443 | Active |
| `<leader>/` | Normal | Fuzzy search in current buffer | init.lua:446-452 | Active |
| `<leader>B` | Normal | Debug: set conditional breakpoint | debug.lua:63-69 | Active |
| `<leader>b` | Normal | Debug: toggle breakpoint | debug.lua:56-62 | Active |
| `<leader>cv` | Normal | Python: open venv-selector picker | custom/plugins/python.lua:11 | Active |
| `<leader>f` | All | Format buffer (conform.nvim) | init.lua:766-773 | Active |
| `<leader>gg` | Normal | Open LazyGit | custom/plugins/ui.lua:69 | Active |
| `<leader>hD` | Normal | Git: diff against last commit | gitsigns.lua:52-54 | Active |
| `<leader>hR` | Normal | Git: reset buffer | gitsigns.lua:48 | Active |
| `<leader>hS` | Normal | Git: stage buffer | gitsigns.lua:46 | Active |
| `<leader>hb` | Normal | Git: blame line | gitsigns.lua:50 | Active |
| `<leader>hd` | Normal | Git: diff against index | gitsigns.lua:51 | Active |
| `<leader>hp` | Normal | Git: preview hunk | gitsigns.lua:49 | Active |
| `<leader>hr` | Normal, Visual | Git: reset hunk | gitsigns.lua:40-45 | Active |
| `<leader>hs` | Normal, Visual | Git: stage hunk | gitsigns.lua:37-44 | Active |
| `<leader>hu` | Normal | Git: undo stage hunk | gitsigns.lua:47 | Active |
| `<leader>jg` | Normal (Java buffers) | Java: generate menu (constructors, getters, setters, getters+setters, toString, equals/hashCode, override/implement methods); each opens a field checkbox picker | custom/plugins/java.lua:160 | Active |
| `<leader>ji` | Normal (Java buffers) | Java: implement/override methods — checkbox picker with abstract interface/parent-class methods listed first and pre-checked | custom/plugins/java.lua:163 | Active |
| `<leader>jm` | Normal (Java buffers) | Java: run/debug nearest test method | custom/plugins/java.lua:159 | Active |
| `<leader>jo` | Normal (Java buffers) | Java: organize imports | custom/plugins/java.lua:157 | Active |
| `<leader>jt` | Normal (Java buffers) | Java: run/debug test class | custom/plugins/java.lua:158 | Active |
| `<leader>mA` | Normal | Notebook: run all cells above the cursor (molten) | custom/plugins/jupyter.lua:426 | Active |
| `<leader>ma` | Normal | Notebook: run all cells (molten) | custom/plugins/jupyter.lua:423 | Active |
| `<leader>md` | Normal | Notebook: delete output of the cell under the cursor | custom/plugins/jupyter.lua:432 | Active |
| `<leader>me` | Normal | Notebook: export outputs into the `.ipynb` file | custom/plugins/jupyter.lua:436 | Active |
| `<leader>mh` | Normal | Notebook: hide output window | custom/plugins/jupyter.lua:431 | Active |
| `<leader>mi` | Normal | Notebook: init kernel (pick from installed kernels, shows each one's interpreter path) | custom/plugins/jupyter.lua:418 | Active |
| `<leader>mj` | Normal | Notebook: insert new code cell below (`` ```python `` fence, or `# %%` in .py), start typing | custom/plugins/jupyter.lua:437 | Active |
| `<leader>mk` | Normal | Notebook: insert new code cell above (`` ```python `` fence, or `# %%` in .py), start typing | custom/plugins/jupyter.lua:440 | Active |
| `<leader>ml` | Normal | Notebook: run current line | custom/plugins/jupyter.lua:422 | Active |
| `<leader>mn` | Normal | Notebook: run cell and jump to next (Shift-Enter) | custom/plugins/jupyter.lua:421 | Active |
| `<leader>mo` | Normal | Notebook: open output window (press again to enter it) | custom/plugins/jupyter.lua:430 | Active |
| `<leader>mq` | Normal | Notebook: stop the buffer's kernels (`:MoltenDeinit`), logs which | custom/plugins/jupyter.lua:435 | Active |
| `<leader>mr` | Normal | Notebook: run current cell | custom/plugins/jupyter.lua:419 | Active |
| `<leader>mr` | Visual | Notebook: run selection | custom/plugins/jupyter.lua:420 | Active |
| `<leader>ms` | Normal | Notebook: restart kernel, clear outputs (asks which if several), logs progress | custom/plugins/jupyter.lua:434 | Active |
| `<leader>mx` | Normal | Notebook: interrupt kernel | custom/plugins/jupyter.lua:433 | Active |
| `<leader>q` | Normal | Open diagnostic quickfix list | init.lua:177 | Active |
| `<leader>r` | Normal | Run current file in a horizontal split terminal (Python, Java) | custom/plugins/run.lua:118 | Active |
| `<leader>s.` | Normal | Search recent files | init.lua:442 | Active |
| `<leader>s/` | Normal | Grep across open files | init.lua:456-461 | Active |
| `<leader>sd` | Normal | Search diagnostics | init.lua:440 | Active |
| `<leader>sf` | Normal | Search files | init.lua:436 | Active |
| `<leader>sg` | Normal | Search by grep (live grep) | init.lua:439 | Active |
| `<leader>sh` | Normal | Search help tags | init.lua:434 | Active |
| `<leader>sk` | Normal | Search keymaps | init.lua:435 | Active |
| `<leader>sn` | Normal | Search Neovim config files | init.lua:464-466 | Active |
| `<leader>sr` | Normal | Search resume (last picker) | init.lua:441 | Active |
| `<leader>ss` | Normal | Search Select Telescope (pick a picker) | init.lua:437 | Active |
| `<leader>sw` | Normal | Search current word | init.lua:438 | Active |
| `<leader>tD` | Normal | Toggle deleted-line preview (git) | gitsigns.lua:57 | Active |
| `<leader>ta` | Normal | Toggle autosave (saves on buffer leave / focus loss / `:q`, not on `<Esc>`) | init.lua:266 | Active |
| `<leader>tb` | Normal | Toggle current-line git blame | gitsigns.lua:56 | Active |
| `<leader>td` | Normal (global; loads neotest on first use) | Test: debug nearest (neotest, via DAP) | custom/plugins/testing.lua:30 | Active |
| `<leader>tf` | Normal (global; loads neotest on first use) | Test: run all tests in file (neotest) | custom/plugins/testing.lua:23 | Active |
| `<leader>th` | Normal | Toggle inlay hints (if server supports it) | init.lua:619-621 | Active |
| `<leader>to` | Normal (global; loads neotest on first use) | Test: toggle output panel (neotest) | custom/plugins/testing.lua:44 | Active |
| `<leader>tr` | Normal (global; loads neotest on first use) | Test: run nearest (neotest) | custom/plugins/testing.lua:16 | Active |
| `<leader>ts` | Normal (global; loads neotest on first use) | Test: toggle summary panel (neotest) | custom/plugins/testing.lua:37 | Active |
| `<leader>tt` | Normal | Toggle integrated terminal (toggleterm) | custom/plugins/ui.lua:58 | Active |
| `<leader>w` | Normal (bufferline) | Close the current tab and go back to the previously used one (MRU order, keeps splits; autosaves, or asks to save if autosave is off) | custom/plugins/ui.lua:21 | Active |
| `<leader>W` | Normal (bufferline) | Reopen the last closed tab (repeat for older ones, like Ctrl+Shift+T) | custom/plugins/ui.lua:28 | Active |
| `<leader>xq` | Normal | Trouble: toggle quickfix list | custom/plugins/ui.lua:50 | Active |
| `<leader>xw` | Normal | Trouble: toggle buffer-only diagnostics | custom/plugins/ui.lua:49 | Active |
| `<leader>xx` | Normal | Trouble: toggle diagnostics (all buffers) | custom/plugins/ui.lua:48 | Active |
| `\` | Normal (global) | Reveal file tree | neo-tree.lua:14 | Active |
| `\` | Normal (inside Neo-tree) | Close Neo-tree window | neo-tree.lua:18-20 | Active |
| `]c` | Normal | Jump to next git change | gitsigns.lua:19-25 | Active |
| `[c` | Normal | Jump to previous git change | gitsigns.lua:27-33 | Active |
| `]x` | Normal | Notebook: jump to next code cell (`` ```python `` fence, or `# %%` in .py) | custom/plugins/jupyter.lua:443 | Active |
| `[x` | Normal | Notebook: jump to previous code cell (`` ```python `` fence, or `# %%` in .py) | custom/plugins/jupyter.lua:446 | Active |
| `<BS>` | Select (snippet placeholder) | Delete placeholder, continue in Insert mode | Vim built-in | Active |
| `<C-e>` | Insert (blink.cmp) | Hide completion menu | blink.cmp default | Active |
| `<C-g>` | Select (snippet placeholder) | Toggle Select ↔ Visual mode (motions move instead of replace) | Vim built-in | Active |
| `<C-h>` | Normal | Move focus to window left | init.lua:197 | Active |
| `<C-j>` | Normal | Move focus to window below | init.lua:199 | Active |
| `<C-k>` | Normal | Move focus to window above | init.lua:200 | Active |
| `<C-k>` | Insert (blink.cmp) | Toggle signature help | blink.cmp default | Active |
| `<C-l>` | Normal | Move focus to window right | init.lua:198 | Active |
| `<C-n>` / `<C-p>`, `<Down>` / `<Up>` | Insert (blink.cmp) | Select next / previous completion item | blink.cmp default | Active |
| `<C-space>` | Insert (blink.cmp) | Open completion menu / show docs if open | blink.cmp default | Active |
| `<C-y>` | Insert (blink.cmp) | Accept selected completion | blink.cmp default | Active |
| `<Tab>` / `<S-Tab>` | Insert, Select (blink.cmp) | Move through snippet placeholders (keeps current placeholder text) | blink.cmp default | Active |
| `<Tab>` | Normal (bufferline) | Next buffer tab | custom/plugins/ui.lua:18 | Active |
| `<S-Tab>` | Normal (bufferline) | Previous buffer tab | custom/plugins/ui.lua:19 | Active |
| `<Esc>` | Select (snippet placeholder) | Exit to Normal mode, keep placeholder text | Vim built-in | Active |
| `<Space>` / `<Tab>` | Normal (Java field picker float) | Toggle the field/method under the cursor, move down | custom/jdtls_picker.lua:82 | Active |
| `a` | Normal (Java field picker float) | Check all / uncheck all | custom/jdtls_picker.lua:88 | Active |
| `<CR>` | Normal (Java field picker float) | Generate with the checked items | custom/jdtls_picker.lua:97 | Active |
| `q` / `<Esc>` | Normal (Java field picker float) | Cancel, insert nothing | custom/jdtls_picker.lua:100 | Active |
| `<F1>` | — | Debug: step into | debug.lua:35-41 | Active |
| `<F2>` | — | Debug: step over | debug.lua:42-48 | Active |
| `<F3>` | — | Debug: step out | debug.lua:49-55 | Active |
| `<F5>` | — | Debug: start/continue | debug.lua:29-34 | Active |
| `<F7>` | — | Debug: toggle UI / see last session result | debug.lua:71-77 | Active |
| `ci'` | Normal (mini.ai default) | Change inside `'` quote | mini.ai default | Active |
| `gc` | Normal, Visual | Toggle comment over a motion (`gcap`) / on the selected lines. Java: several lines get wrapped in `/*` `*/`; on a `/* */` block, uncomments it | Neovim built-in; Java: custom/block_comment.lua | Active |
| `gc` | Operator | Comment-block text object (`dgc` deletes the block). Java: also selects a `/* */` block | Neovim built-in; Java: custom/block_comment.lua | Active |
| `gcc` | Normal | Toggle comment on the current line (`3gcc` for 3 lines). Java: inside a `/* */` block, uncomments the whole block; `3gcc` wraps in `/* */` | Neovim built-in; Java: custom/block_comment.lua | Active |
| `gO` | Normal | Open document symbols (only if the LSP supports it; else Neovim's built-in outline, e.g. markdown headings) | init.lua:573-575 | Active |
| `gW` | Normal | Open workspace symbols | init.lua:579 | Active |
| `gra` | Normal, Visual | LSP code action | init.lua:549 | Active |
| `grd` | Normal | LSP goto definition (`<C-t>` jumps back) | init.lua:561 | Active |
| `grD` | Normal | LSP goto declaration | init.lua:565 | Active |
| `gri` | Normal | LSP goto implementation | init.lua:556 | Active |
| `grn` | Normal | LSP rename symbol | init.lua:545 | Active |
| `grr` | Normal | LSP goto references | init.lua:552 | Active |
| `grt` | Normal | LSP goto type definition | init.lua:584 | Active |
| `sa}` (linewise) | Normal (`saip}`, `sa2j}`), Visual-line (mini.surround default) | Wrap lines in `{`/`}` on their own lines and indent them (`respect_selection_type`) | mini.surround default | Active |
| `saiw)` | Normal (mini.surround default) | Surround add around inner word with `)` | mini.surround default | Active |
| `sd'` | Normal (mini.surround default) | Surround delete `'` | mini.surround default | Active |
| `sr)'` | Normal (mini.surround default) | Surround replace `)` with `'` | mini.surround default | Active |
| `va)` | Normal, Visual (mini.ai default) | Select around `)` (includes parens) | mini.ai default | Active |
| `yinq` | Normal (mini.ai default) | Yank inside next quote | mini.ai default | Active |

**Keymap namespace notes** (checked while adding the rows above, to avoid silent prefix-shadowing):
- `<leader>b` / `<leader>B` are complete bindings (debug breakpoints) — bufferline deliberately
  avoids a `<leader>b*` prefix and uses bare `<Tab>`/`<S-Tab>` instead.
- `<leader>t*` now holds `th`, `ta`, `tb`, `tD`, `tt`, `tr`, `tf`, `td`, `ts`, `to` — all distinct at
  the second character (or distinguished by case, e.g. `tb` vs `tD`/`td`), so none shadows another.
- `<leader>x*` (trouble) and `<leader>j*` (Java) and `<leader>c*` (`cv`, venv) and `<leader>g*`
  (`gg`, lazygit) were previously unused prefixes.
- `<leader>m*` (molten / Jupyter notebooks) was previously unused; every binding under it is two
  keys, so none shadows another (`ma` vs `mA` differ by case). `<leader>j*` stays Java-only.
- `<leader>w` / `<leader>W` (close / reopen buffer tab) were previously unused, and nothing else
  starts with them, so they fire without a which-key wait.
- `<leader>r` (run current file) was previously unused, and nothing else starts with `<leader>r`,
  so it fires without a which-key wait.
- `]x` / `[x` (next/previous notebook cell) were picked because `]c` / `[c` belong to gitsigns.

See [cheatsheet.md](cheatsheet.md) for grouped explanations, which-key group labels, and
per-language notes (Python/Jupyter/Java/C/Web/Docker/Shell/LaTeX).
