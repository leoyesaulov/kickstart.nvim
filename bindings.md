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
| `<leader><leader>` | Normal | Find existing buffers | init.lua:438 | Active |
| `<leader>/` | Normal | Fuzzy search in current buffer | init.lua:441-447 | Active |
| `<leader>B` | Normal | Debug: set conditional breakpoint | debug.lua:63-69 | Active |
| `<leader>b` | Normal | Debug: toggle breakpoint | debug.lua:56-62 | Active |
| `<leader>cv` | Normal | Python: open venv-selector picker | custom/plugins/python.lua:11 | Active |
| `<leader>f` | All | Format buffer (conform.nvim) | init.lua:767-774 | Active |
| `<leader>gg` | Normal | Open LazyGit | custom/plugins/ui.lua:50 | Active |
| `<leader>hD` | Normal | Git: diff against last commit | gitsigns.lua:52-54 | Active |
| `<leader>hR` | Normal | Git: reset buffer | gitsigns.lua:48 | Active |
| `<leader>hS` | Normal | Git: stage buffer | gitsigns.lua:46 | Active |
| `<leader>hb` | Normal | Git: blame line | gitsigns.lua:50 | Active |
| `<leader>hd` | Normal | Git: diff against index | gitsigns.lua:51 | Active |
| `<leader>hp` | Normal | Git: preview hunk | gitsigns.lua:49 | Active |
| `<leader>hr` | Normal, Visual | Git: reset hunk | gitsigns.lua:40-45 | Active |
| `<leader>hs` | Normal, Visual | Git: stage hunk | gitsigns.lua:37-44 | Active |
| `<leader>hu` | Normal | Git: undo stage hunk | gitsigns.lua:47 | Active |
| `<leader>jm` | Normal (Java buffers) | Java: run/debug nearest test method | custom/plugins/java.lua:93 | Active |
| `<leader>jo` | Normal (Java buffers) | Java: organize imports | custom/plugins/java.lua:91 | Active |
| `<leader>jt` | Normal (Java buffers) | Java: run/debug test class | custom/plugins/java.lua:92 | Active |
| `<leader>q` | Normal | Open diagnostic quickfix list | init.lua:177 | Active |
| `<leader>s.` | Normal | Search recent files | init.lua:437 | Active |
| `<leader>s/` | Normal | Grep across open files | init.lua:451-456 | Active |
| `<leader>sd` | Normal | Search diagnostics | init.lua:435 | Active |
| `<leader>sf` | Normal | Search files | init.lua:431 | Active |
| `<leader>sg` | Normal | Search by grep (live grep) | init.lua:434 | Active |
| `<leader>sh` | Normal | Search help tags | init.lua:429 | Active |
| `<leader>sk` | Normal | Search keymaps | init.lua:430 | Active |
| `<leader>sn` | Normal | Search Neovim config files | init.lua:459-461 | Active |
| `<leader>sr` | Normal | Search resume (last picker) | init.lua:436 | Active |
| `<leader>ss` | Normal | Search Select Telescope (pick a picker) | init.lua:432 | Active |
| `<leader>sw` | Normal | Search current word | init.lua:433 | Active |
| `<leader>tD` | Normal | Toggle deleted-line preview (git) | gitsigns.lua:57 | Active |
| `<leader>tb` | Normal | Toggle current-line git blame | gitsigns.lua:56 | Active |
| `<leader>td` | Normal (Python buffers) | Test: debug nearest (neotest, via DAP) | custom/plugins/testing.lua:30 | Active |
| `<leader>tf` | Normal (Python buffers) | Test: run all tests in file (neotest) | custom/plugins/testing.lua:23 | Active |
| `<leader>th` | Normal | Toggle inlay hints (if server supports it) | init.lua:622-624 | Active |
| `<leader>to` | Normal (Python buffers) | Test: toggle output panel (neotest) | custom/plugins/testing.lua:44 | Active |
| `<leader>tr` | Normal (Python buffers) | Test: run nearest (neotest) | custom/plugins/testing.lua:16 | Active |
| `<leader>ts` | Normal (Python buffers) | Test: toggle summary panel (neotest) | custom/plugins/testing.lua:37 | Active |
| `<leader>tt` | Normal | Toggle integrated terminal (toggleterm) | custom/plugins/ui.lua:39 | Active |
| `<leader>xq` | Normal | Trouble: toggle quickfix list | custom/plugins/ui.lua:31 | Active |
| `<leader>xw` | Normal | Trouble: toggle buffer-only diagnostics | custom/plugins/ui.lua:30 | Active |
| `<leader>xx` | Normal | Trouble: toggle diagnostics (all buffers) | custom/plugins/ui.lua:29 | Active |
| `\` | Normal (global) | Reveal file tree | neo-tree.lua:14 | Active |
| `\` | Normal (inside Neo-tree) | Close Neo-tree window | neo-tree.lua:18-20 | Active |
| `]c` | Normal | Jump to next git change | gitsigns.lua:19-25 | Active |
| `[c` | Normal | Jump to previous git change | gitsigns.lua:27-33 | Active |
| `<C-e>` | Insert (blink.cmp) | Hide completion menu | blink.cmp default | Active |
| `<C-h>` | Normal | Move focus to window left | init.lua:197 | Active |
| `<C-j>` | Normal | Move focus to window below | init.lua:199 | Active |
| `<C-k>` | Normal | Move focus to window above | init.lua:200 | Active |
| `<C-k>` | Insert (blink.cmp) | Toggle signature help | blink.cmp default | Active |
| `<C-l>` | Normal | Move focus to window right | init.lua:198 | Active |
| `<C-n>` / `<C-p>`, `<Down>` / `<Up>` | Insert (blink.cmp) | Select next / previous completion item | blink.cmp default | Active |
| `<C-space>` | Insert (blink.cmp) | Open completion menu / show docs if open | blink.cmp default | Active |
| `<C-y>` | Insert (blink.cmp) | Accept selected completion | blink.cmp default | Active |
| `<Tab>` / `<S-Tab>` | Insert (blink.cmp) | Move through snippet placeholders | blink.cmp default | Active |
| `<Tab>` | Normal (bufferline) | Next buffer tab | custom/plugins/ui.lua:13 | Active |
| `<S-Tab>` | Normal (bufferline) | Previous buffer tab | custom/plugins/ui.lua:14 | Active |
| `<F1>` | — | Debug: step into | debug.lua:35-41 | Active |
| `<F2>` | — | Debug: step over | debug.lua:42-48 | Active |
| `<F3>` | — | Debug: step out | debug.lua:49-55 | Active |
| `<F5>` | — | Debug: start/continue | debug.lua:29-34 | Active |
| `<F7>` | — | Debug: toggle UI / see last session result | debug.lua:71-77 | Active |
| `ci'` | Normal (mini.ai default) | Change inside `'` quote | mini.ai default | Active |
| `gO` | Normal | Open document symbols | init.lua:564 | Active |
| `gW` | Normal | Open workspace symbols | init.lua:568 | Active |
| `gra` | Normal, Visual | LSP code action | init.lua:544 | Active |
| `grd` | Normal | LSP goto definition (`<C-t>` jumps back) | init.lua:556 | Active |
| `grD` | Normal | LSP goto declaration | init.lua:560 | Active |
| `gri` | Normal | LSP goto implementation | init.lua:551 | Active |
| `grn` | Normal | LSP rename symbol | init.lua:540 | Active |
| `grr` | Normal | LSP goto references | init.lua:547 | Active |
| `grt` | Normal | LSP goto type definition | init.lua:573 | Active |
| `saiw)` | Normal (mini.surround default) | Surround add around inner word with `)` | mini.surround default | Active |
| `sd'` | Normal (mini.surround default) | Surround delete `'` | mini.surround default | Active |
| `sr)'` | Normal (mini.surround default) | Surround replace `)` with `'` | mini.surround default | Active |
| `va)` | Normal, Visual (mini.ai default) | Select around `)` (includes parens) | mini.ai default | Active |
| `yinq` | Normal (mini.ai default) | Yank inside next quote | mini.ai default | Active |

**Keymap namespace notes** (checked while adding the rows above, to avoid silent prefix-shadowing):
- `<leader>b` / `<leader>B` are complete bindings (debug breakpoints) — bufferline deliberately
  avoids a `<leader>b*` prefix and uses bare `<Tab>`/`<S-Tab>` instead.
- `<leader>t*` now holds `th`, `tb`, `tD`, `tt`, `tr`, `tf`, `td`, `ts`, `to` — all distinct at the
  second character (or distinguished by case, e.g. `tb` vs `tD`/`td`), so none shadows another.
- `<leader>x*` (trouble) and `<leader>j*` (Java) and `<leader>c*` (`cv`, venv) and `<leader>g*`
  (`gg`, lazygit) were previously unused prefixes.

See [cheatsheet.md](cheatsheet.md) for grouped explanations, which-key group labels, and
per-language notes (Python/Java/C/Web/Docker/Shell/LaTeX).
