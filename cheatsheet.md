# Neovim Cheatsheet

Leader key: `<Space>` &nbsp;|&nbsp; Localleader: `<Space>` &nbsp;|&nbsp; Plugin manager: lazy.nvim

### Navigating this file in Neovim

`marksman` (markdown LSP) is configured, so `gd` on a `[text](#anchor)` link jumps to the heading and `gO` lists headings in Telescope. Without it (e.g. marksman not installed yet), these built-ins still work:

| Key / Command | Action |
|---|---|
| `gO` | Fuzzy-find headings (Telescope); without a symbol-capable LSP, falls back to Neovim's outline in the location list |
| `/^## Basics<CR>` | Jump to a chapter by searching for its heading |
| `yi[` then `/<C-r>"<CR>`, `n` | From a TOC entry: yank the link text, search for it, `n` until you land on the heading |
| `<leader>/` | Fuzzy-search the buffer (Telescope) — type a chapter name, `<CR>` to jump |
| `]]` / `[[` | Next / previous heading |
| `<C-o>` / `<C-i>` | Jump back / forward through the jumplist — returns you to the TOC after any of the above |
| ` `` ` | Toggle between current position and the last jump |
| `gg` | Top of file (the TOC is right below) |
| `mt` … `'t` | Set mark `t` at the TOC, return to it from anywhere |

## Table of Contents
1. [Basics](#basics)
2. [Core / Window Navigation](#core--window-navigation)
3. [Everyday Editing](#everyday-editing) — commenting, undo, clipboard, search & replace, macros
4. [Search & Telescope](#search--telescope)
5. [LSP](#lsp)
6. [Formatting](#formatting)
7. [Linting](#linting)
8. [Completion (blink.cmp)](#completion-blinkcmp)
9. [Text Objects & Surround (mini.nvim)](#text-objects--surround-mininvim)
10. [Git (gitsigns)](#git-gitsigns)
11. [Git Panel (lazygit.nvim)](#git-panel-lazygitnvim)
12. [File Explorer (neo-tree)](#file-explorer-neo-tree)
13. [Buffer Tabs (bufferline.nvim)](#buffer-tabs-bufferlinenvim)
14. [Problems Panel (trouble.nvim)](#problems-panel-troublenvim)
15. [Integrated Terminal (toggleterm.nvim)](#integrated-terminal-togglermnvim)
16. [Running Files](#running-files)
17. [Debugging (DAP)](#debugging-dap)
18. [Testing (neotest)](#testing-neotest)
19. [Markdown Preview (markview.nvim)](#markdown-preview-markviewnvim)
20. [Python](#python)
21. [Jupyter Notebooks (molten.nvim)](#jupyter-notebooks-moltennvim)
22. [Java](#java)
23. [C / C++](#c--c)
24. [Web Dev](#web-dev)
25. [DevOps (Docker, Compose, nginx, CI YAML)](#devops-docker-compose-nginx-ci-yaml)
26. [Shell](#shell)
27. [LaTeX](#latex)
28. [Misc Commands](#misc-commands)

---

## Basics

| Command | Description |
|---|---|
| `:Tutor` | Built-in interactive Neovim tutorial — start here if new |
| `:Lazy` | Open lazy.nvim plugin manager UI |
| `:Lazy update` | Update all plugins (pins land in the repo's `lazy-lock.json` — commit them) |
| `:Lazy restore` | Roll plugins back to the versions pinned in `lazy-lock.json` |
| `:Mason` | Manage installed LSP servers / formatters / linters / debuggers (`g?` for help inside) |
| `:checkhealth` | Run health checks (Neovim version, `git`, `make`, `unzip`, `rg`, `fd`, `tree-sitter` presence) |

**Leader groups** (which-key labels shown after pressing `<Space>`): `s` Search, `t` Toggle/Test,
`h` Git hunk, `m` Molten (notebooks), `x` Trouble (diagnostics), `j` Java, `c` Code, `g` Git. `r` alone runs the current file.

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

## Everyday Editing

Built-in Neovim keys and the options `init.lua` turns on. None of these are custom mappings, but
they're the ones worth learning first. `:help <key>` explains any of them (e.g. `:help gcc`).

### Commenting

Built into Neovim (0.10+), no plugin. Uses the filetype's `'commentstring'` and is Treesitter-aware,
so it picks the right comment style for embedded code: JS inside HTML, a ```` ```python ````
fence in markdown or a notebook.

| Key | Mode | Action |
|---|---|---|
| `gcc` | Normal | Toggle comment on the current line (`3gcc` = this line and the next 2) |
| `gc{motion}` | Normal | Toggle comment over a motion: `gcap` paragraph, `gc2j` 3 lines, `gcG` to end of file |
| `gc` | Visual | Toggle comment on the selected lines (`V`, `jj`, `gc`) |
| `gc` | Operator-pending | Text object for the comment block around the cursor: `dgc` deletes it, `gcgc` uncomments it |
| `.` | Normal | Repeat the last comment toggle on another line |

**Java** (`lua/custom/block_comment.lua`) also understands `/* */` block comments:

- Commenting **several** lines (`Vjjgc`, `gcap`, `3gcc`) wraps them in `/*` and `*/`, each on its
  own line at the block's indent. A single line still gets `//`, and lines that are all `//`
  comments are still uncommented by removing the `//`.
- `gcc`, `gc{motion}` or Visual `gc` that touches a `/* */` block removes its delimiters. That
  covers own-line `/*` and `*/`, inline `/* foo … bar */`, and the ` * ` decorated style.
  `gcgc` does the same and `dgc` deletes the block.
- Javadoc (`/** … */`) and trailing comments (`f(); /* x */`) are left alone and get the
  normal `//` toggle.

### Editing

| Key | Action |
|---|---|
| `u` / `<C-r>` | Undo / redo. Undo history is saved to disk (`undofile`), so it survives closing the file |
| `:earlier 10m` / `:later 10m` | Jump the buffer back / forward in time (also `5f` = 5 saves ago) |
| `.` | Repeat the last change |
| `yyp` / `yyP` | Duplicate the line below / above |
| `ddp` / `ddkP` | Move the line down / up (or `:m +1` / `:m -2`; Visual: `:m '>+1` / `:m '<-2`) |
| `J` / `gJ` | Join the next line onto this one, with / without a space |
| `>>` / `<<` | Indent / dedent the line. In Visual, `>` / `<`, then `gv` reselects to do it again |
| `=ap` / `gg=G` | Re-indent the paragraph / whole file (`<leader>f` formats properly with the LSP/formatter) |
| `~` / `gUiw` / `guiw` | Toggle case of a char / UPPERCASE a word / lowercase a word |
| `<C-a>` / `<C-x>` | Increment / decrement the number under or after the cursor (`5<C-a>` adds 5) |
| `g<C-a>` | Visual: turn a column of `0`s into `1, 2, 3, …` |
| `<C-v>` then `I` / `$A` | Block select, then insert at the start / append at the end of every line. `<Esc>` applies it |
| `gi` | Go back into Insert mode where you last left it |
| `gv` | Reselect the last Visual selection |
| `cl` | Replace one character and type (Vim's `s`; here `s` is the mini.surround prefix) |

Indent width is detected per file by `guess-indent.nvim`, so `>>` and `<Tab>` match the file's
existing style. Typing `(`, `[`, `{`, `"` or `'` inserts the closing one too (nvim-autopairs);
typing the closer skips over it, `<BS>` deletes the pair, `<CR>` between `{}` opens an indented
block.

**In Insert mode:** `<C-w>` deletes the word before the cursor, `<C-u>` deletes to the start of the
line, `<C-r>{reg}` pastes a register (`<C-r>"` last yank/delete, `<C-r>0` last yank), and `<C-o>`
runs a single Normal-mode command, then returns to Insert.

### Clipboard & registers

The clipboard is synced with the OS (`clipboard=unnamedplus`): `y` copies to the system clipboard
and `p` pastes from it. **Deletes copy too**, so `dd`/`x`/`c` overwrite whatever you copied.

| Key | Action |
|---|---|
| `"_dd` / `"_x` / `"_ciw` | Delete or change into the black hole register, leaving the clipboard alone |
| `"0p` | Paste the last **yank**, even after deleting things since |
| `P` | Visual: replace the selection with the clipboard, without copying the replaced text (paste it again on the next selection) |
| `"ayy` / `"ap` | Yank into / paste from named register `a` (any letter); `"Ayy` appends to it |
| `:reg` | Show what's in every register |

### Search & replace

| Key / Command | Action |
|---|---|
| `/text` / `?text` | Search forward / backward; `n` / `N` next / previous match |
| `*` / `#` | Search for the word under the cursor, forward / backward |
| *(automatic)* | Lowercase searches ignore case; any capital letter makes it case-sensitive (`\C` forces it) |
| `:%s/old/new/g` | Replace in the whole file. A split previews every change live as you type (`inccommand`) |
| `:%s/old/new/gc` | Same, but ask `y`/`n`/`a`(all)/`q` at each match |
| `V` … `:s/old/new/g` | Replace only in the selected lines (`:'<,'>` is filled in for you) |
| `*` then `cgn` new `<Esc>`, `.` `.` | Change the next match, then `.` changes each following one. `n` skips one |
| `<leader>sg` | Search the whole project (see [Search & Telescope](#search--telescope)) |

### Moving around

| Key | Action |
|---|---|
| `<C-d>` / `<C-u>` | Scroll half a page down / up |
| `zz` / `zt` / `zb` | Scroll so the cursor line is centered / at the top / at the bottom |
| `%` | Jump to the matching bracket |
| `{` / `}` | Previous / next blank line (paragraph) |
| `f{char}` / `t{char}` | Jump to / just before the next `{char}` on the line; `;` / `,` repeat forward / back. `F` / `T` go left |
| `g;` / `g,` | Jump back / forward through the places you **edited** (changelist) |
| `<C-o>` / `<C-i>` | Jump back / forward through the places you **jumped** (jumplist) |
| `<C-^>` | Switch to the previous buffer |
| `gf` | Open the file path under the cursor |
| `ma` … `` `a `` | Set mark `a`, jump back to it. Capital letters (`mA`) work across files |

> `<C-i>` and `<Tab>` are the same key in terminals that don't support the extended keyboard
> protocol, so there `<C-i>` switches buffer tabs (bufferline) instead of jumping forward.
> Ghostty and kitty tell them apart.

### Windows, buffers & files

| Key / Command | Action |
|---|---|
| `<C-w>v` / `<C-w>s` | Split vertically (opens right) / horizontally (opens below) |
| `<C-h/j/k/l>` | Move between windows (see [Core](#core--window-navigation)) |
| `<C-w>q` / `<C-w>o` | Close this window / close every other window |
| `<C-w>=` | Make all windows the same size. Or drag a split's border with the mouse |
| `<leader>w` / `<leader>W` | Close the current buffer tab and go back to the previous one / reopen the last closed tab (see [Buffer Tabs](#buffer-tabs-bufferlinenvim)) |
| `:bd` | Close the current buffer the plain way: also closes its window if it's in a split |
| `:w` / `:wa` | Save / save all |
| `:q` / `:qa` | Quit the window / quit everything. With unsaved changes you're asked whether to save (`confirm`) |
| `ZZ` / `ZQ` | Save and quit / quit without saving |
| `:e!` | Throw away unsaved changes and reload the file from disk |

### Spelling

| Key / Command | Action |
|---|---|
| `:set spell` / `:set nospell` | Underline misspelled words in this window (comments and strings only, in code) |
| `]s` / `[s` | Next / previous misspelled word |
| `z=` | Suggestions for the word under the cursor (`1z=` takes the first one) |
| `zg` / `zw` | Add the word to your dictionary / mark it as wrong |

### Macros

| Key | Action |
|---|---|
| `qa` … `q` | Record keystrokes into register `a` |
| `@a` / `@@` | Play macro `a` / play the last played macro again (`10@a` = 10 times) |
| `Q` | Replay the last **recorded** macro |
| `V` … `:norm @a` | Run macro `a` on every selected line |

### TODO comments

`todo-comments.nvim` highlights `TODO:`, `FIXME:`, `HACK:`, `WARN:`, `PERF:`, `NOTE:` and `TEST:` in
comments (the colon matters). It ships no keymaps; these commands list them:

| Command | Action |
|---|---|
| `:TodoTelescope` | Fuzzy-find every TODO/FIXME/... in the project |
| `:Trouble todo` | Same list in the [Trouble](#problems-panel-troublenvim) panel |
| `:TodoQuickFix` | Same list in the quickfix window |

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

Triggered on `LspAttach`, buffer-local. Configured servers: `gopls`, `pyright`, `ruff`, `clangd`,
`lua_ls`, `ts_ls`, `html`, `cssls`, `tailwindcss`, `jsonls`, `eslint`, `emmet_language_server`,
`dockerls`, `docker_compose_language_service`, `yamlls`, `nginx_language_server`, `bashls`, `texlab`,
`marksman` (markdown). **Java (`jdtls`) is not in
this list** — it's started separately with its own lifecycle, see [Java](#java).

| Key | Mode | Action |
|---|---|---|
| `grn` | Normal | Rename symbol |
| `gra` | Normal, Visual | Code action |
| `grr` | Normal | Goto references |
| `gri` | Normal | Goto implementation |
| `grd` | Normal | Goto definition (jump back with `<C-t>`) |
| `grD` | Normal | Goto declaration |
| `grt` | Normal | Goto type definition |
| `gO` | Normal | Open document symbols (only mapped if the server supports them) |
| `gW` | Normal | Open workspace symbols |
| `<leader>th` | Normal | Toggle inlay hints (if server supports it) |

**Behavior:** hovering the cursor briefly highlights other references to the symbol under it (clears on cursor move).

## Formatting

| Key / Command | Action |
|---|---|
| `<leader>f` | Format current buffer (works for every filetype below, including C/C++ via clangd) |
| *(automatic)* | Format on save (LSP fallback; **skipped** for `c`/`cpp` — format manually with `<leader>f` instead) |
| `:ConformInfo` | Show formatter info for current buffer |

Formatters by filetype: `lua` → stylua, `sh` → shfmt, `javascript`/`typescript`/
`javascriptreact`/`typescriptreact`/`html`/`css`/`scss`/`json`/`yaml` → prettierd (falls back to
prettier). Compose files and GitHub workflows (`yaml.docker-compose`, `yaml.github`) use the
`yaml` formatter too. **Python has no separate formatter here** — ruff's LSP server handles
formatting + import-sorting directly (see [Python](#python)). **C/C++ has no separate formatter
either** — clangd's own `textDocument/formatting` covers it via LSP fallback.

## Linting

`nvim-lint`, runs automatically on `BufEnter`/`BufWritePost`/`InsertLeave` for modifiable buffers.

| Filetype | Linter |
|---|---|
| `dockerfile` | hadolint |
| `sh`, `bash` | shellcheck |
| `yaml.github` (`.github/workflows/*.yml`) | actionlint (also shellchecks `run:` scripts) |

## Completion (blink.cmp)

| Key | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | Move right/left through snippet placeholders (Insert/Select mode) |
| `<C-space>` | Open completion menu / show docs if already open |
| `<C-n>` / `<C-p>` or `<Down>` / `<Up>` | Select next / previous item |
| `<C-y>` | Accept selected completion |
| `<C-e>` | Hide completion menu |
| `<C-k>` | Toggle signature help |

Sources: LSP, path, snippets (LuaSnip), lazydev (Neovim Lua API). Your own snippets go in
`lua/custom/snippets/<filetype>.lua`. Currently that's Java only, see [Java snippets](#java-snippets).

**Usage ranking (Java, Python):** items you accept often in the current project (git root, or the
nearest `pom.xml`/`build.gradle`/`pyproject.toml`/...) rank higher, by up to +12 score (about one
matched character). Overloads share a count. After `obj.` the members you use most come first.
Stats are per project in `~/.local/state/nvim/completion-usage/`. Delete a project's file to reset it.

**Completing mid-word:** if the rest of the word after the cursor is exactly the end of the item,
it's replaced instead of duplicated: `new UnknownBlueprint|Exception()` + `UnknownBlueprintException`
→ `new UnknownBlueprintException()`. A tail that doesn't match is kept (`Unknown|Foo` +
`UnknownError` → `UnknownErrorFoo`).

**Empty lines:** the first character you type on an empty line (where Vim has dropped the
autoindent) first gives the line the indent its context needs. So snippets and completions typed
there expand at the right column, and so does every line of a multi-line snippet like `fori`.
Not used in Python, YAML, Markdown, Make or plain text, where indentation means something.
Opening the menu with `<C-Space>` before typing anything doesn't reindent.

> Note: `<Tab>`/`<S-Tab>` are also bound in **Normal mode** by bufferline.nvim (see
> [Buffer Tabs](#buffer-tabs-bufferlinenvim)) — no conflict, since blink.cmp's mapping is
> Insert/Select-mode only.

### Snippet placeholders (Select mode)

Accepting a function completion (e.g. a Java method) inserts its argument names as snippet
placeholders and drops you into **Select mode** (`-- SELECT --` in the statusline) on the first
one. In Select mode, any typed character **replaces the whole placeholder** — that's how you fill
in arguments.

| Key | Action |
|---|---|
| *type anything* | Replace the placeholder with what you type |
| `<Tab>` | Keep this placeholder, jump to the next one (after the last, jumps past the call) |
| `<S-Tab>` | Jump back to the previous placeholder |
| `<BS>` | Delete the placeholder, stay in Insert mode at that spot |
| `<Esc>` | Bail out to Normal mode, placeholder text kept as-is |
| `<C-g>` | Toggle Select ↔ Visual mode (so `h`/`l`/`w` move instead of replacing) |

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

Gutter signs (`+` / `~` / `_` / `‾` next to changed lines) plus the full hunk-navigation/
stage/reset/blame keymap set below.

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

## Git Panel (lazygit.nvim)

Floating `lazygit` TUI inside Neovim — stage, commit, push/pull, browse branches, without
reinventing those flows as native keymaps. Needs the `lazygit` binary (installed by `install.sh`).

| Key | Action |
|---|---|
| `<leader>gg` | Open LazyGit |

## File Explorer (neo-tree)

| Key | Action |
|---|---|
| `\` | Reveal file tree (Normal, global) |
| `\` | Close Neo-tree window (inside Neo-tree) |

## Buffer Tabs (bufferline.nvim)

Shows open buffers as IDE-style tabs along the top, with LSP diagnostic icons per tab.

| Key | Mode | Action |
|---|---|---|
| `<Tab>` | Normal | Next buffer tab |
| `<S-Tab>` | Normal | Previous buffer tab |
| `<leader>w` | Normal | Close the current tab and go back to the one you used before it |
| `<leader>W` | Normal | Reopen the last closed tab |

Closing works like a browser: `<leader>w` goes back through the tabs **in the order you last
used them**, not to the tab next to it, so pressing it repeatedly walks back through your
history. Splits and the file tree stay where they are, and if the buffer has unsaved changes you
get a Yes/No/Cancel save prompt. `<leader>W` is Ctrl+Shift+T: closed tabs form a stack, so
pressing it again brings back older ones, each at the line where you closed it.

## Problems Panel (trouble.nvim)

Aggregated diagnostics/quickfix list — the closest analog to an IDE's "Problems" panel.

| Key | Action |
|---|---|
| `<leader>xx` | Toggle diagnostics (all buffers) |
| `<leader>xw` | Toggle diagnostics (current buffer only) |
| `<leader>xq` | Toggle quickfix list |

## Integrated Terminal (toggleterm.nvim)

| Key | Action |
|---|---|
| `<leader>tt` | Toggle a floating terminal |

## Running Files

`<leader>r` saves the current file and runs it in a terminal split across the bottom
(`lua/custom/plugins/run.lua`). The program can read stdin, and the output stays open after it
exits: `<Esc><Esc>` then `:q` to close it, or just run again, which replaces the previous run's
terminal. It never touches your `<leader>tt` shell. Running under the debugger is still `<F5>`.

| Filetype | Runs |
|---|---|
| Python | `python <file>` from the file's directory. Interpreter: the venv picked with `<leader>cv`, else `$VIRTUAL_ENV`, else `.venv/` at the project root, else `python3` |
| Java, in a project (jdtls attached) | Builds the workspace, then runs **this file's** class with the classpath and JDK jdtls resolved, from the project root. Refuses if the file has compile errors or no `main` |
| Java, loose file (no jdtls) | `java <file>` (single-file source launch, Java 11+). Only works if the file uses no other project classes |

Other filetypes show "no runner for <filetype>". To add one, add a `runners.<filetype>` function
to `run.lua`: it gets the file path and calls `done(argv, cwd)`.

## Debugging (DAP)

Shared `nvim-dap` + `nvim-dap-ui` base (`lua/kickstart/plugins/debug.lua`). Keymaps work the same
across every supported language; what differs is which `dap.configurations.<lang>` get populated:

| Key | Action |
|---|---|
| `<F5>` | Start / Continue debugging |
| `<F1>` | Step into |
| `<F2>` | Step over |
| `<F3>` | Step out |
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Set conditional breakpoint |
| `<F7>` | Toggle debug UI / see last session result |

Per-language adapters: **Go** → delve (stock), **Python** → debugpy (needs
`lua/custom/plugins/python.lua`'s venv/debugpy wiring), **C/C++** → codelldb (prompts for the
executable path on launch), **Java** → wired through `nvim-jdtls` once it attaches (see
[Java](#java)) rather than a static adapter here.

## Testing (neotest)

Run or debug a single test under the cursor, PyCharm-gutter-style. **Python only** — Java/C
neotest adapters are unmaintained, so those two languages test via the DAP debugger directly
(breakpoint in a test method, `<F5>`) or a terminal (`mvn test` / `gradle test` / `make test`).

| Key | Action |
|---|---|
| `<leader>tr` | Run nearest test |
| `<leader>tf` | Run all tests in file |
| `<leader>td` | Debug nearest test (stops at breakpoints) |
| `<leader>ts` | Toggle summary panel |
| `<leader>to` | Toggle output panel |

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

## Python

- `pyright` (types) + `ruff` (lint, format, import-sort — no separate black/isort) attach on every `.py` buffer.
- `<leader>cv` — open the venv-selector picker (poetry/conda/virtualenv/pipenv); updates pyright's resolved interpreter.
- `<leader>r` — run the current file with the selected venv's interpreter, see [Running Files](#running-files).
- Debugging: debugpy via the shared [DAP](#debugging-dap) keymaps (`<F5>`, `<leader>b`, ...).
- Testing: [neotest](#testing-neotest) (`<leader>tr`/`<leader>tf`/`<leader>td`/...), debug-nearest shares the debugpy adapter above.
- Notebooks: see [Jupyter Notebooks](#jupyter-notebooks-moltennvim) — `.ipynb` opens as markdown; the same `<leader>m*` keys run `# %%` cells in plain `.py` files too.

## Jupyter Notebooks (molten.nvim)

Run notebooks inside Neovim, no browser (`lua/custom/plugins/jupyter.lua`). Five plugins work
together:

- **jupytext.nvim** — opening `foo.ipynb` shows it as **markdown**: markdown cells are plain
  markdown, code cells are ```` ```python ```` fenced blocks. `:w` writes everything back into
  `foo.ipynb` and keeps the outputs already stored in it.
- **markview.nvim** — renders the markdown cells in normal mode (headings, bold, lists, tables,
  code-block backgrounds); insert mode shows the raw text.
- **otter.nvim** — gives the code cells real Python LSP: pyright + ruff run on a hidden
  `foo.ipynb.otter.py` buffer, so completion, hover (`K`), go-to-definition, rename and ruff
  diagnostics work inside the fences. `:w` / `<leader>f` format code cells with ruff
  (`conform`'s `injected` formatter); the markdown is left as is.
- **molten.nvim** — talks to a real Jupyter kernel. Short output shows as virtual text under the
  cell, longer output in a float (`<leader>mo`).
- **image.nvim** — draws plots and images inline. Only enabled in **Kitty or Ghostty** (detected
  from `$KITTY_WINDOW_ID` / `$TERM` / `$TERM_PROGRAM` at startup). In other terminals output is
  text-only, so a matplotlib plot shows up as `<Figure ...>`. Inside tmux, add
  `set -g allow-passthrough on` to `~/.tmux.conf`.

`install.sh` sets up a dedicated venv at `~/.local/share/nvim/molten-venv` (pynvim,
jupyter_client, ipykernel, jupytext, nbformat). Neovim uses it as its Python host. Its `python3`
kernel is good enough for scratch work without any project setup.

### Basic workflow

1. `nvim foo.ipynb` — the notebook opens as rendered markdown with ```` ```python ```` code cells.
2. `<leader>mi` — pick a kernel (`python3`, or your project's kernel, see below). Wait for
   `Kernel 'python3' ... is ready`.
3. Move between code cells with `]x` / `[x` (lands on the first code line). Run the cell under
   the cursor with `<leader>mr`, or use `<leader>mn` to run it and jump to the next one (like
   Shift-Enter in Jupyter; from markdown text it just jumps to the next code cell). `<leader>ma`
   runs everything.
4. Output appears under the cell. `<leader>mo` opens it in a float (do it again to enter the float
   and scroll; `:q` or `<leader>mh` closes it).
5. Add code cells with `<leader>mj` (below) / `<leader>mk` (above). Markdown cells are just text
   between code cells — type anywhere outside a fence. **Two blank lines** split one markdown cell
   into two (that's how jupytext tells them apart).
6. `:w` saves the code into `foo.ipynb`. Then `<leader>me` writes the **outputs** into it too, so
   they're there when someone opens it in Jupyter or GitHub. Outputs are *not* exported
   automatically.
7. `<leader>ms` restarts the kernel (state lost), `<leader>mx` interrupts a long-running cell,
   `<leader>mq` stops the kernel.

**New notebook:** create `foo.ipynb` (e.g. neo-tree `a`) and open it — an empty Python 3 notebook
is seeded automatically. Or write `foo.py` with `# %%` cells and run it right there with the same
keys (no `.ipynb` needed; in `.py` files cells are `# %%` blocks and `# %% [markdown]` cells are
skipped), or convert it: `jupytext --to ipynb --set-kernel python3 foo.py`. `jupytext` lives in
the molten venv: `~/.local/share/nvim/molten-venv/bin/jupytext`.

**Per-project/subject kernel:** a kernel is a venv with `ipykernel`, registered under a name.
Once per project:

```sh
python3 -m venv .venv && source .venv/bin/activate   # fish: activate.fish
pip install ipykernel
python -m ipykernel install --user --name myproject --display-name "My Project"
```

Then `<leader>mi` lists `myproject`; `<leader>cv` points pyright at the same `.venv`.

- **Install dependencies:** `pip install numpy ...` with the venv activated, or `%pip install
  numpy ...` in a notebook cell (always targets the running kernel; plain `!pip` may not).
  Restart the kernel (`<leader>ms`) before importing a package installed mid-session.
- **Pin it in the notebook** so Jupyter/VS Code pick it too: `jupytext --set-kernel myproject foo.ipynb`.
- **List/remove:** `jupyter kernelspec list` / `jupyter kernelspec remove myproject` (both in the
  molten venv's `bin/`). Deleting `.venv` alone leaves a broken entry, marked `(missing!)` in
  `<leader>mi`; a venv without ipykernel is marked `(no ipykernel!)`.
- **Slow or dead kernel:** while a kernel boots, `<leader>mi` reports progress every 5s. If the
  kernel process dies during startup it says so and stops molten (otherwise molten polls the dead
  kernel forever, freezing nvim ~1s per poll).

| Key | Mode | Action |
|---|---|---|
| `<leader>mi` | Normal | Init kernel (picker shows each kernel's interpreter path) |
| `<leader>mr` | Normal | Run current cell |
| `<leader>mr` | Visual | Run selection |
| `<leader>mn` | Normal | Run cell, jump to next |
| `<leader>ml` | Normal | Run current line |
| `<leader>ma` | Normal | Run all cells |
| `<leader>mA` | Normal | Run all cells above the cursor |
| `]x` / `[x` | Normal | Next / previous cell |
| `<leader>mj` / `<leader>mk` | Normal | New cell below / above |
| `<leader>mo` | Normal | Open output float (again: enter it) |
| `<leader>mh` | Normal | Hide output float |
| `<leader>md` | Normal | Delete the cell's output |
| `<leader>mx` | Normal | Interrupt kernel |
| `<leader>ms` | Normal | Restart kernel, clear outputs (logs progress like a start) |
| `<leader>mq` | Normal | Stop kernel (logs which ones stopped) |
| `<leader>me` | Normal | Export outputs into the `.ipynb` |

Markdown text and code cells that only contain comments are skipped when running. Fences inside
jupytext's `<!-- #region -->` … `<!-- #endregion -->` blocks are code samples within a markdown
cell, not cells.

**Gotchas / troubleshooting**
- While `foo.ipynb` is open, jupytext.nvim keeps a temporary `foo.md` next to it and deletes it on
  close. If a `foo.md` **already exists** there, it is opened *instead of* the notebook's content
  and left alone. Rename one of them if they're unrelated. (A leftover `foo.py` from the old
  `# %%` setup no longer matters and can be deleted.)
- No completion/diagnostics in code cells → `:checkhealth vim.lsp` in the notebook should list `otter-ls`;
  otter only activates for `.ipynb` buffers, not plain `.md` files.
- A notebook with no `kernelspec` in its metadata fails to open. Fix it with
  `jupytext --set-kernel python3 foo.ipynb`.
- `E492: Not an editor command: MoltenInit` → run `:UpdateRemotePlugins`, restart nvim.
- `:checkhealth provider` should show the molten venv's Python with pynvim; `:checkhealth molten`
  checks jupyter_client and the image provider.

## Java

`nvim-jdtls` (`lua/custom/plugins/java.lua`) attaches on `FileType java`, **only inside a real
Maven/Gradle project** (root markers: `pom.xml`, `build.gradle`, `build.gradle.kts`,
`settings.gradle`, or `.git`) — a loose `.java` file with no build descriptor gets degraded
single-file support, same as IntelliJ without a project. Each project gets its own workspace dir
under `stdpath('cache')/jdtls-workspace/<project>`.

| Key | Action |
|---|---|
| `<leader>jo` | Organize imports |
| `<leader>jt` | Run/debug the current test class |
| `<leader>jm` | Run/debug the nearest test method |
| `<leader>r` | Run this file's `main` in a split terminal, see [Running Files](#running-files) (works without jdtls too) |
| `<leader>jg` | Generate menu, like IntelliJ's Alt+Insert: Constructors… / Getters… / Setters… / Getters and Setters… / `toString()` / `equals()`/`hashCode()` / Override/Implement Methods… |
| `<leader>ji` | Implement/override methods, like IntelliJ's Ctrl+I: stubs for the abstract methods of the class's interfaces and parent classes |

Each generate action opens a checkbox list of the class's fields (`[x] name: Type`), so you pick
which fields go into the constructor or get accessors. Getters/setters start with every field
checked; constructors start unchecked (jdtls's default). Fields that already have the accessor, and
setters for `final` fields, aren't listed. Picking zero fields for a constructor gives a no-arg one.

Implement/override (`<leader>ji`, or Override/Implement Methods… in the menu) uses the same picker.
Abstract methods from interfaces and parent classes come first, marked `(abstract)` and already
checked, so `<leader>ji` `<CR>` stubs out everything the class still has to implement. Other
overridable methods (`toString`, `equals`, non-abstract parent methods, …) are listed unchecked
below them. Also, on a class with the "must implement the inherited abstract method" error, `gra`
offers jdtls's "Add unimplemented methods" quick fix, which adds all of them with no picker.

Generated code (`<leader>jg`, `<leader>ji`, multi-line completions) is indented like the current
buffer. Tabs vs. spaces and the width come from `expandtab`/`shiftwidth`, which guess-indent detects
from the file. Change them with `:set` and the next generated code follows.

| Key (in the picker) | Action |
|---|---|
| `<Space>` / `<Tab>` | Toggle the field/method under the cursor, move down |
| `a` | Check all / uncheck all |
| `<CR>` | Generate with the checked items |
| `q` / `<Esc>` | Cancel, nothing is inserted |

**Automatic `package` line.** When you open a `.java` file that has no `package` declaration,
`package …;` and a blank line are added at the top, worked out from the path under the nearest
`src/`: `src/de/tum/cit/aet/pse/Foo.java` gives `de.tum.cit.aet.pse`, and the Maven/Gradle
`src/main/java/com/x/Foo.java` gives `com.x`. The rest of the file isn't touched, and this works
on new and empty files too (without jdtls). It's skipped when the path has no `src/`, when the
file is directly in `src/` (default package), or when a folder name isn't a valid Java identifier.
The buffer is then unsaved; `u` undoes the insert.

### Java snippets

Type the trigger and accept it from the completion menu with `<C-y>` (snippets show a `~` after the
label, then a short description). Then `<Tab>`/`<S-Tab>` move between placeholders. These come from
`lua/custom/snippets/java.lua` and work even without jdtls. jdtls's own Eclipse-style templates
(`sysout`, `ifelse`, `class`, ...) are filtered out of the menu, since these snippets replace them.
Its postfix templates (`list.for`, `x.nnull`, `x.var`) still show after `.`. Snippets are hidden
right after `.`/`::`, so `obj.` only lists the object's methods, fields and postfix templates.

**How the names work:**
1. Well-known IntelliJ abbreviations stay as they are: `sout`, `souf`, `soutv`, `psvm`, `fori`.
2. Everything else is a **family prefix + variant letter**: `try` → `tryc`/`tryf`/`tryr`,
   `if` → `ife`/`ifn`/`ifnn`, `thr` → `thria`/`thris`/`thrus`.
3. A suffix letter means the same thing in every family: `f` = format/finally,
   `r` = reverse/resources, `e` = else/enhanced, `n` = null, `nn` = not null.
4. Methods, fields and classes have their own grammar, **kind + access + modifiers**. Every
   valid combination exists, so you build the trigger instead of memorizing it:

   | Part | Letters |
   |---|---|
   | Kind | `m` method · `f` field · `cls` class |
   | Access | none = public · `p` private · `t` protected (classes are always public) |
   | Modifiers, in Java order | `a` abstract · `s` static · `f` final. For classes, add `e` extends · `i` implements · `ei` both |

   Examples: `m` public method, `mt` protected method, `mts` protected static method, `mta` protected
   abstract method (just `;`, no body), `fpf` private final field, `ftsf` protected static final constant
   (`NAME = …`), `clsa` abstract class, `clsae` abstract class extends, `clsfi` final class implements.
   Private abstract (`mpa`) doesn't exist, since nothing could override it.

| Family | Triggers |
|---|---|
| Print (`so` = out, `se` = err) | `sout` println · `souf` printf · `soutv` `"x = " + x` · `soutm` `"Class.method"` · `soutp` all method params · `serr` · `serf` |
| Entry point | `psvm` / `main` |
| Loops | `fori` index · `forr` reverse index · `fore` for-each · `wh` while · `dowh` do-while |
| Conditionals | `if` if · `ife` if/else · `ifn` if null · `ifnn` if not null · `elif` else-if |
| Switch | `sw` arrow switch · `swe` switch expression (`var x = switch …`) |
| Try | `tryc` catch · `tryf` finally · `trycf` catch+finally · `tryr` try-with-resources |
| Throw | `thr` any `…Exception` · `thria` IllegalArgument · `thris` IllegalState · `thrus` UnsupportedOperation |
| Declarations (rule 4) | `m…` methods · `f…` fields · `cls…` classes (name from file) |
| Types (name from file) | `intf` interface · `enm` enum · `rec` record |
| Constructors | `ctor` no-arg · `ctorp` one param + `this.x = x` · `fin` init one field (`this.items = new ArrayList<>();`, `this.n = 0;`) · `fina` init all remaining fields |
| Accessors | `get` getter · `is` boolean getter · `set` setter · `gs` getter+setter · `fgs` field+getter+setter |
| Collections (impl initials) | `al` ArrayList · `hm` HashMap · `hs` HashSet |
| Misc | `ov` `@Override` · `test` JUnit 5 `@Test` method · `rnn` `Objects.requireNonNull(x, "x")` · `new` `Object obj = new Object()`, or just `new Object()` inside an argument list / after `=`, `return`, `->` · `scan` `Scanner(System.in)` |

In the accessor snippets you type the type and the field name once. The method names are built
as you type: typing `age` gives `getAge`/`setAge`.

In any `cls…e`/`cls…i`/`cls…ei` snippet, start typing the parent or interface name and pick it from the jdtls
completion menu (`<c-y>` also adds the import). Then `<leader>ji` stubs the methods you must implement.

**Snippet or `<leader>jg`?** Use the snippet when the field doesn't exist yet: `fgs` writes the
field and both accessors in one go. Use `<leader>jg` when the fields already exist and you want
a constructor or accessors for several of them. It shows a picker of the real fields and needs
jdtls to be attached.

**Initialising fields in a constructor.** `<leader>jg`'s constructor only assigns the fields
you take as parameters. For the rest, type `fin` or `fina` inside the constructor body. They're
only listed there, and only while some field is still uninitialised: not static, no `= …` in
its declaration, not a constructor parameter, and not assigned in the constructor yet.
- `fin` fills in the first such field: `this.items = new ArrayList<>();`. To pick another field,
  type over the name and press `<Tab>`. The right-hand side is rebuilt from that field's type.
- `fina` writes one line per field. `<Tab>` steps through each type or value.
- Interfaces get a common implementation: `List`/`Collection` → `ArrayList`, `Set` → `HashSet`,
  `Map` → `HashMap`, `Queue`/`Deque` → `ArrayDeque`, `Sorted…`/`Navigable…` → `Tree…`. Generic
  types use `<>`. Any other class is used as written, and you can type over it to swap in an
  implementation. Arrays become `new int[0]`.
- Types `new` doesn't fit get a default value instead: `0`, `0L`, `0f`, `0.0`, `false`, `'\0'`,
  and `""` for `String`. Boxed types (`Integer`, …) get the same value as their primitive.
- Imports aren't added. Run `<leader>jo` afterwards, or `gra` on the error.

Debugging a `main` method or a test uses the same shared [DAP](#debugging-dap) keymaps
(`<F5>`, `<leader>b`, ...) once jdtls generates a run configuration. `<F5>` lists every main class
in the project; to just run the current file's, use `<leader>r`.

**"Security Warning! The gradle wrapper … could be malicious"**: jdtls only trusts
`gradle-wrapper.jar` files whose sha256 is on Gradle's published list, and it treats every
wrapper as untrusted if it can't download that list (offline, proxy). If you trust the project,
run `:JdtTrustGradleWrapper`. It saves the jar's checksum to
`stdpath('data')/jdtls-trusted-gradle-wrappers.json` and restarts jdtls, and the checksum stays
trusted for every project that uses the same wrapper. If the warning is still there after
that, run `:JdtWipeDataAndRestart`.

## C / C++

- `clangd` attaches on `.c`/`.cpp`/headers — **needs a per-project `compile_commands.json` or
  `compile_flags.txt`** to give real diagnostics/completion instead of just syntax highlighting.
  Generate one with `bear -- make`, or CMake's `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. This is a
  per-project setup step, not something this config automates.
- Formatting: no separate conform entry — clangd's own formatting covers it via LSP fallback.
  Format-on-save is intentionally **off** for `c`/`cpp`; use `<leader>f` manually.
- Debugging: codelldb via the shared [DAP](#debugging-dap) keymaps; `<F5>` prompts for the
  executable path to launch.

## Web Dev

LSP servers: `ts_ls` (JS/TS/React), `html`, `cssls`, `tailwindcss`, `jsonls`, `eslint`,
`emmet_language_server` (fast markup/CSS expansion). Formatting on save via prettierd/prettier
for js/ts/jsx/tsx/html/css/scss/json/yaml (see [Formatting](#formatting)). ESLint's code actions
(`gra`) cover quick-fixes like unused imports.

## DevOps (Docker, Compose, nginx, CI YAML)

| File | Filetype | LSP | Lint |
|---|---|---|---|
| `Dockerfile`, `Containerfile`, `*.Dockerfile` | `dockerfile` | `dockerls` | hadolint |
| `compose.yaml`, `docker-compose.yml`, `docker-compose.*.yml`, `compose.*.yaml` | `yaml.docker-compose` | `docker_compose_language_service` + `yamlls` | — |
| `.github/workflows/*.yml` | `yaml.github` | `yamlls` | actionlint |
| other `*.yml` / `*.yaml` | `yaml` | `yamlls` | — |
| `nginx.conf`, `/etc/nginx/**`, `*/nginx/*.conf`, `*.nginx`, `*/nginx/sites-*/*`, `*/nginx/**/*.conf.template` | `nginx` | `nginx_language_server` | — |

- The compose/workflow/extra nginx patterns are defined in `lua/custom/filetypes.lua`. Neovim
  detects compose files as plain `yaml` on its own, which keeps the compose LSP from starting.
- `yamlls` and `jsonls` get schemas from SchemaStore.nvim's catalog: completion, hover docs and
  validation for compose, GitHub Actions, GitLab CI, `package.json`, `tsconfig.json`, etc., picked
  by filename. Hover (`K`) on a key shows its schema docs.
- `:checkhealth vim.lsp` shows which servers attached to the current buffer.
- `nginx_language_server` is installed by `install.sh` with `uv tool install --python 3.13`, not
  Mason (its Mason package needs Python <3.14). Without it, nginx files still get highlighting
  but no LSP.
- YAML (compose and workflows included) formats with prettierd on save. nginx has no formatter.

## Shell

`bashls` LSP, shellcheck lint, shfmt format-on-save (see [Formatting](#formatting) /
[Linting](#linting)).

## LaTeX

`vimtex` (compilation via `latexmk`, forward/backward PDF sync, folding) + `texlab` LSP
(completion/diagnostics). Needs a TeX distribution providing `latexmk` and a PDF viewer —
both installed by `install.sh` (`ensure_tex_distribution`/`ensure_pdf_viewer`; Linux uses
zathura, macOS falls back to Skim/Preview).

| Command | Action |
|---|---|
| `:VimtexCompile` | Start/stop a `latexmk` watch-build of the current document |
| `:VimtexView` | Forward-search: jump the PDF viewer to the current line |

## Misc Commands

| Command | Description |
|---|---|
| `:Telescope colorscheme` | Browse and preview installed colorschemes |
| `:ConformInfo` | Formatter info for current buffer |
| `:Mason` | LSP/tool installer UI |
| `:Lazy` | Plugin manager UI |
| `:checkhealth` | Diagnose environment/config issues |
| `:VenvSelect` | Python interpreter/venv picker |
| `:Trouble` | Open the problems panel |
| `:ToggleTerm` | Open the integrated terminal |
| `:LazyGit` | Open the floating lazygit panel |
| `:MoltenInit` | Start a Jupyter kernel for the current buffer |
| `:MoltenInfo` | Show molten's kernels and status |
