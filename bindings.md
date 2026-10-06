# Keybindings Reference

Flat, sorted-by-key reference of every binding in this config. For a narrative, topic-grouped
walkthrough see [cheatsheet.md](cheatsheet.md).

Leader: `<Space>`. Status `Active` = loaded right now; `Disabled` = defined in a plugin file
under `lua/kickstart/plugins/` whose `require(...)` is commented out in `init.lua`'s
`lazy.setup{}` call.

| Key | Mode | Action | Source | Status |
|---|---|---|---|---|
| `<Esc>` | Normal | Clear search highlight | init.lua:174 | Active |
| `<Esc><Esc>` | Terminal | Exit terminal mode to Normal (fallback `<C-\><C-n>`) | init.lua:185 | Active |
| `<leader><leader>` | Normal | Find existing buffers | init.lua:438 | Active |
| `<leader>/` | Normal | Fuzzy search in current buffer | init.lua:441-447 | Active |
| `<leader>B` | Normal | Debug: set conditional breakpoint | debug.lua:64-70 | Disabled |
| `<leader>b` | Normal | Debug: toggle breakpoint | debug.lua:57-63 | Disabled |
| `<leader>f` | All | Format buffer (conform.nvim) | init.lua:745-751 | Active |
| `<leader>hD` | Normal | Git: diff against last commit | gitsigns.lua:52-54 | Disabled |
| `<leader>hR` | Normal | Git: reset buffer | gitsigns.lua:48 | Disabled |
| `<leader>hS` | Normal | Git: stage buffer | gitsigns.lua:46 | Disabled |
| `<leader>hb` | Normal | Git: blame line | gitsigns.lua:50 | Disabled |
| `<leader>hd` | Normal | Git: diff against index | gitsigns.lua:51 | Disabled |
| `<leader>hp` | Normal | Git: preview hunk | gitsigns.lua:49 | Disabled |
| `<leader>hr` | Normal, Visual | Git: reset hunk | gitsigns.lua:40-45 | Disabled |
| `<leader>hs` | Normal, Visual | Git: stage hunk | gitsigns.lua:37-44 | Disabled |
| `<leader>hu` | Normal | Git: undo stage hunk | gitsigns.lua:47 | Disabled |
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
| `<leader>tD` | Normal | Toggle deleted-line preview (git) | gitsigns.lua:57 | Disabled |
| `<leader>tb` | Normal | Toggle current-line git blame | gitsigns.lua:56 | Disabled |
| `<leader>th` | Normal | Toggle inlay hints (if server supports it) | init.lua:622-624 | Active |
| `\` | Normal (global) | Reveal file tree | neo-tree.lua:14 | Disabled |
| `\` | Normal (inside Neo-tree) | Close Neo-tree window | neo-tree.lua:18-20 | Disabled |
| `]c` | Normal | Jump to next git change | gitsigns.lua:19-25 | Disabled |
| `[c` | Normal | Jump to previous git change | gitsigns.lua:27-33 | Disabled |
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
| `<F1>` | — | Debug: step into | debug.lua:36-42 | Disabled |
| `<F2>` | — | Debug: step over | debug.lua:43-49 | Disabled |
| `<F3>` | — | Debug: step out | debug.lua:50-56 | Disabled |
| `<F5>` | — | Debug: start/continue | debug.lua:30-35 | Disabled |
| `<F7>` | — | Debug: toggle UI / see last session result | debug.lua:72-78 | Disabled |
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

See [cheatsheet.md](cheatsheet.md) for grouped explanations, which-key group labels
(`<leader>s` = "[S]earch", `<leader>t` = "[T]oggle", `<leader>h` = "Git [H]unk"), and notes on
enabling the disabled plugins.
