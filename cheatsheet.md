# Neovim Cheatsheet

Leader key: `<Space>` &nbsp;|&nbsp; Localleader: `<Space>` &nbsp;|&nbsp; Plugin manager: lazy.nvim

## Table of Contents
1. [Basics](#basics)
2. [Core / Window Navigation](#core--window-navigation)
3. [Search & Telescope](#search--telescope)
4. [LSP](#lsp)
5. [Formatting](#formatting)
6. [Completion (blink.cmp)](#completion-blinkcmp)
7. [Text Objects & Surround (mini.nvim)](#text-objects--surround-mininvim)
8. [Git (gitsigns)](#git-gitsigns)
9. [Markdown Preview (markview.nvim)](#markdown-preview-markviewnvim)
10. [Available but Disabled ⚠️](#available-but-disabled-️)
11. [Misc Commands](#misc-commands)

---

## Basics

| Command | Description |
|---|---|
| `:Tutor` | Built-in interactive Neovim tutorial — start here if new |
| `:Lazy` | Open lazy.nvim plugin manager UI |
| `:Lazy update` | Update all plugins |
| `:Mason` | Manage installed LSP servers / formatters / tools (`g?` for help inside) |
| `:checkhealth` | Run health checks (Neovim version, `git`, `make`, `unzip`, `rg` presence) |

## Core / Window Navigation

| Key | Mode | Action |
|---|---|---|
| `<Esc>` | Normal | Clear search highlight |
| `<leader>q` | Normal | Open diagnostics quickfix list |
| `<Esc><Esc>` | Terminal | Exit terminal mode to Normal (fallback: `<C-\><C-n>`) |
| `<C-h>` | Normal | Move focus to window left |
| `<C-l>` | Normal | Move focus to window right |
| `<C-j>` | Normal | Move focus to window below |
| `<C-k>` | Normal | Move focus to window above |

**Behavior:** Yanked text briefly highlights (`TextYankPost` autocommand) — try `yap`.

## Search & Telescope

| Key | Action |
|---|---|
| `<leader>sh` | Search Help tags |
| `<leader>sk` | Search Keymaps |
| `<leader>sf` | Search Files |
| `<leader>ss` | Search Select Telescope (pick a picker) |
| `<leader>sw` | Search current Word |
| `<leader>sg` | Search by Grep (live grep) |
| `<leader>sd` | Search Diagnostics |
| `<leader>sr` | Search Resume (last picker) |
| `<leader>s.` | Search recent files |
| `<leader><leader>` | Find existing buffers |
| `<leader>/` | Fuzzy search in current buffer |
| `<leader>s/` | Grep across open files |
| `<leader>sn` | Search Neovim config files |

**Inside any Telescope picker:** `<C-/>` (Insert) or `?` (Normal) shows that picker's keymaps.

## LSP

Triggered on `LspAttach`, buffer-local. Configured servers: `gopls`, `pyright`, `lua_ls`.

| Key | Mode | Action |
|---|---|---|
| `grn` | Normal | Rename symbol |
| `gra` | Normal, Visual | Code action |
| `grr` | Normal | Goto references |
| `gri` | Normal | Goto implementation |
| `grd` | Normal | Goto definition (jump back with `<C-t>`) |
| `grD` | Normal | Goto declaration |
| `grt` | Normal | Goto type definition |
| `gO` | Normal | Open document symbols |
| `gW` | Normal | Open workspace symbols |
| `<leader>th` | Normal | Toggle inlay hints (if server supports it) |

**Behavior:** hovering the cursor briefly highlights other references to the symbol under it (clears on cursor move).

## Formatting

| Key / Command | Action |
|---|---|
| `<leader>f` | Format current buffer |
| *(automatic)* | Format on save (LSP fallback; skipped for `c`/`cpp`) |
| `:ConformInfo` | Show formatter info for current buffer |

## Completion (blink.cmp)

| Key | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | Move right/left through snippet placeholders |
| `<C-space>` | Open completion menu / show docs if already open |
| `<C-n>` / `<C-p>` or `<Down>` / `<Up>` | Select next / previous item |
| `<C-y>` | Accept selected completion |
| `<C-e>` | Hide completion menu |
| `<C-k>` | Toggle signature help |

Sources: LSP, path, snippets (LuaSnip), lazydev (Neovim Lua API).

## Text Objects & Surround (mini.nvim)

| Key | Action |
|---|---|
| `va)` | Select **a**round `)` (includes parens) |
| `yinq` | Yank **i**nside **n**ext quote |
| `ci'` | Change **i**nside `'` quote |
| `saiw)` | **S**urround **a**dd around inner word with `)` |
| `sd'` | **S**urround **d**elete `'` |
| `sr)'` | **S**urround **r**eplace `)` with `'` |

## Git (gitsigns)

Only gutter signs are currently active (`+` / `~` / `_` / `‾` next to changed lines). Hunk navigation and staging keymaps are **not** bound — see [Available but Disabled](#available-but-disabled-️) to enable them.

## Markdown Preview (markview.nvim)

Active by default (loaded eagerly, no filetype trigger needed) — renders markdown **in the buffer itself** via Treesitter as you type/move the cursor; there's no separate preview window or browser. No default keymaps ship with the plugin, so bind the commands below yourself if you want quick access.

| Command | Scope | Action |
|---|---|---|
| `:Markview toggle` | Current buffer | Switch rendering on/off |
| `:Markview Toggle` | Global | Switch rendering on/off everywhere |
| `:Markview hybridToggle` | Current buffer | Toggle hybrid mode (shows raw markdown on the line your cursor is on, rendered elsewhere) |
| `:Markview splitOpen` | Current buffer | Open a separate preview window instead of inline rendering |
| `:Markview splitClose` | Current buffer | Close that split preview |
| `:Markview splitToggle` | Current buffer | Toggle the split preview |

## Available but Disabled ⚠️

These plugin files exist in `lua/kickstart/plugins/` but their `require(...)` lines are **commented out** in `init.lua` (around lines 976–987), so none of the keymaps below currently work. Uncomment the relevant line to enable.

### Debug / DAP (`debug.lua`)
| Key | Action |
|---|---|
| `<F5>` | Start / Continue debugging |
| `<F1>` | Step into |
| `<F2>` | Step over |
| `<F3>` | Step out |
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Set conditional breakpoint |
| `<F7>` | Toggle debug UI / see last session result |

### Neo-tree file explorer (`neo-tree.lua`)
| Key | Action |
|---|---|
| `\` | Reveal file tree (Normal, global) |
| `\` | Close Neo-tree window (inside Neo-tree) |

### Extended Gitsigns (`gitsigns.lua`)
| Key | Mode | Action |
|---|---|---|
| `]c` | Normal | Jump to next git change |
| `[c` | Normal | Jump to previous git change |
| `<leader>hs` | Normal, Visual | Stage hunk |
| `<leader>hr` | Normal, Visual | Reset hunk |
| `<leader>hS` | Normal | Stage buffer |
| `<leader>hu` | Normal | Undo stage hunk |
| `<leader>hR` | Normal | Reset buffer |
| `<leader>hp` | Normal | Preview hunk |
| `<leader>hb` | Normal | Blame line |
| `<leader>hd` | Normal | Diff against index |
| `<leader>hD` | Normal | Diff against last commit |
| `<leader>tb` | Normal | Toggle current-line blame |
| `<leader>tD` | Normal | Toggle deleted-line preview |

### Other disabled plugins (no keymaps — automatic behavior)
- **autopairs.lua** — auto-closes brackets/quotes while typing
- **lint.lua** — runs `nvim-lint` (markdownlint) on markdown files on enter/save/insert-leave
- **indent_line.lua** — indent-blankline.nvim visual indentation guides

## Misc Commands

| Command | Description |
|---|---|
| `:Telescope colorscheme` | Browse and preview installed colorschemes |
| `:ConformInfo` | Formatter info for current buffer |
| `:Mason` | LSP/tool installer UI |
| `:Lazy` | Plugin manager UI |
| `:checkhealth` | Diagnose environment/config issues |
