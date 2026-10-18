# Neovim Cheatsheet

Leader key: `<Space>` &nbsp;|&nbsp; Localleader: `<Space>` &nbsp;|&nbsp; Plugin manager: lazy.nvim

### Navigating this file in Neovim

There's no markdown LSP configured, so `gd` won't follow `[text](#anchor)` links. Use built-ins instead:

| Key / Command | Action |
|---|---|
| `gO` | Open an outline of all headings in the location list — `<CR>` jumps to one (Neovim 0.11+) |
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
3. [Search & Telescope](#search--telescope)
4. [LSP](#lsp)
5. [Formatting](#formatting)
6. [Linting](#linting)
7. [Completion (blink.cmp)](#completion-blinkcmp)
8. [Text Objects & Surround (mini.nvim)](#text-objects--surround-mininvim)
9. [Git (gitsigns)](#git-gitsigns)
10. [Git Panel (lazygit.nvim)](#git-panel-lazygitnvim)
11. [File Explorer (neo-tree)](#file-explorer-neo-tree)
12. [Buffer Tabs (bufferline.nvim)](#buffer-tabs-bufferlinenvim)
13. [Problems Panel (trouble.nvim)](#problems-panel-troublenvim)
14. [Integrated Terminal (toggleterm.nvim)](#integrated-terminal-togglermnvim)
15. [Debugging (DAP)](#debugging-dap)
16. [Testing (neotest)](#testing-neotest)
17. [Markdown Preview (markview.nvim)](#markdown-preview-markviewnvim)
18. [Python](#python)
19. [Jupyter Notebooks (molten.nvim)](#jupyter-notebooks-moltennvim)
20. [Java](#java)
21. [C / C++](#c--c)
22. [Web Dev](#web-dev)
23. [Docker](#docker)
24. [Shell](#shell)
25. [LaTeX](#latex)
26. [Misc Commands](#misc-commands)

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
`h` Git hunk, `m` Molten (notebooks), `x` Trouble (diagnostics), `j` Java, `c` Code, `g` Git.

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

Triggered on `LspAttach`, buffer-local. Configured servers: `gopls`, `pyright`, `ruff`, `clangd`,
`lua_ls`, `ts_ls`, `html`, `cssls`, `tailwindcss`, `jsonls`, `eslint`, `emmet_language_server`,
`dockerls`, `docker_compose_language_service`, `bashls`, `texlab`. **Java (`jdtls`) is not in
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
| `gO` | Normal | Open document symbols |
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
prettier). **Python has no separate formatter here** — ruff's LSP server handles
formatting + import-sorting directly (see [Python](#python)). **C/C++ has no separate formatter
either** — clangd's own `textDocument/formatting` covers it via LSP fallback.

## Linting

`nvim-lint`, runs automatically on `BufEnter`/`BufWritePost`/`InsertLeave` for modifiable buffers.

| Filetype | Linter |
|---|---|
| `markdown` | markdownlint |
| `dockerfile` | hadolint |
| `sh`, `bash` | shellcheck |

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

Active by default (loaded eagerly, no filetype trigger needed) — renders markdown **in the buffer itself** via Treesitter as you type/move the cursor; there's no separate preview window or browser. No default keymaps ship with the plugin, so bind the commands below yourself if you want quick access. markdownlint (see [Linting](#linting)) runs alongside it independently.

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
- Debugging: debugpy via the shared [DAP](#debugging-dap) keymaps (`<F5>`, `<leader>b`, ...).
- Testing: [neotest](#testing-neotest) (`<leader>tr`/`<leader>tf`/`<leader>td`/...), debug-nearest shares the debugpy adapter above.
- Notebooks: see [Jupyter Notebooks](#jupyter-notebooks-moltennvim) — the same `<leader>m*` keys run `# %%` cells in plain `.py` files too.

## Jupyter Notebooks (molten.nvim)

Run notebooks inside Neovim, no browser (`lua/custom/plugins/jupyter.lua`). Three plugins work
together:

- **jupytext.nvim** — opening `foo.ipynb` shows it as plain Python in *percent* format: each cell
  starts with a `# %%` line, markdown cells are `# %% [markdown]` followed by `#` comment lines.
  pyright, ruff, completion and treesitter all work as in any `.py` file. `:w` writes the code back
  into `foo.ipynb` and keeps the outputs already stored in it.
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

1. `nvim foo.ipynb` — the notebook opens as `# %%` cells.
2. `<leader>mi` — pick a kernel (`python3`, or your project's kernel, see below). Wait for
   `Kernel 'python3' ... is ready`.
3. Move with `]x` / `[x`. Run the cell under the cursor with `<leader>mr`, or use `<leader>mn` to
   run it and jump to the next one (like Shift-Enter in Jupyter). `<leader>ma` runs everything.
4. Output appears under the cell. `<leader>mo` opens it in a float (do it again to enter the float
   and scroll; `:q` or `<leader>mh` closes it).
5. Add cells with `<leader>mj` (below) / `<leader>mk` (above). Edit code like any Python file.
6. `:w` saves the code into `foo.ipynb`. Then `<leader>me` writes the **outputs** into it too, so
   they're there when someone opens it in Jupyter or GitHub. Outputs are *not* exported
   automatically.
7. `<leader>ms` restarts the kernel (state lost), `<leader>mx` interrupts a long-running cell,
   `<leader>mq` stops the kernel.

**New notebook:** write `foo.py` with `# %%` cells and run it right there (no `.ipynb` needed), or
convert it: `jupytext --to ipynb --set-kernel python3 foo.py`. `jupytext` lives in the molten venv:
`~/.local/share/nvim/molten-venv/bin/jupytext`.

**Use a project's venv (its packages) as the kernel:** once per venv, with the venv activated:

```sh
pip install ipykernel
python -m ipykernel install --user --name myproject
```

Then `<leader>mi` lists `myproject`.

| Key | Mode | Action |
|---|---|---|
| `<leader>mi` | Normal | Init kernel (pick from installed kernels) |
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
| `<leader>ms` | Normal | Restart kernel |
| `<leader>mq` | Normal | Stop kernel |
| `<leader>me` | Normal | Export outputs into the `.ipynb` |

Markdown cells and cells that only contain comments are skipped when running.

**Gotchas / troubleshooting**
- While `foo.ipynb` is open, jupytext.nvim keeps a temporary `foo.py` next to it and deletes it on
  close. If a `foo.py` **already exists** there, it is opened *instead of* the notebook's content
  and left alone. Rename one of them if they're unrelated.
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
| `<leader>jg` | Generate menu: constructor, getters/setters, `toString()`, `equals()`/`hashCode()` from the class's fields (like IntelliJ's Alt+Insert) |

### Java snippets

Type the trigger and accept it from the completion menu with `<C-y>` (snippets show a `~` after the
label). Then `<Tab>`/`<S-Tab>` move between placeholders. These come from
`lua/custom/snippets/java.lua` and work even without jdtls. jdtls also sends its own Eclipse-style
templates (`sysout`, `foreach`, ...), but these snippets are ranked above them.

**How the names work:**
1. Well-known IntelliJ abbreviations stay as they are: `sout`, `souf`, `soutv`, `psvm`, `fori`, `psf`.
2. Everything else is a **family prefix + variant letter**: `try` → `tryc`/`tryf`/`tryr`,
   `if` → `ife`/`ifn`/`ifnn`, `thr` → `thria`/`thris`/`thrus`.
3. A suffix letter means the same thing in every family: `f` = format/finally,
   `r` = reverse/resources, `e` = else/enhanced, `n` = null, `nn` = not null.

| Family | Triggers |
|---|---|
| Print (`so` = out, `se` = err) | `sout` println · `souf` printf · `soutv` `"x = " + x` · `soutm` `"Class.method"` · `soutp` all method params · `serr` · `serf` |
| Entry point | `psvm` / `main` |
| Loops | `fori` index · `forr` reverse index · `fore` for-each · `wh` while · `dowh` do-while |
| Conditionals | `ife` if/else · `ifn` if null · `ifnn` if not null · `elif` else-if |
| Switch | `sw` arrow switch · `swe` switch expression (`var x = switch …`) |
| Try | `tryc` catch · `tryf` finally · `trycf` catch+finally · `tryr` try-with-resources |
| Throw | `thr` any `…Exception` · `thria` IllegalArgument · `thris` IllegalState · `thrus` UnsupportedOperation |
| Types (name from file) | `cls` class · `intf` interface · `enm` enum · `rec` record |
| Constructors | `ctor` no-arg · `ctorp` one param + `this.x = x` |
| Fields / constants | `prv` private · `prf` private final · `psf` public static final · `prsf` private static final |
| Accessors | `get` getter · `is` boolean getter · `set` setter · `gs` getter+setter · `fgs` field+getter+setter |
| Methods | `m` public · `mp` private · `ms` public static |
| Collections (impl initials) | `al` ArrayList · `hm` HashMap · `hs` HashSet |
| Misc | `ov` `@Override` · `test` JUnit 5 `@Test` method · `rnn` `Objects.requireNonNull(x, "x")` · `scan` `Scanner(System.in)` |

In the accessor snippets you type the type and the field name once. The method names are built
as you type: typing `age` gives `getAge`/`setAge`.

**Snippet or `<leader>jg`?** Use the snippet when the field doesn't exist yet: `fgs` writes the
field and both accessors in one go. Use `<leader>jg` when the fields already exist and you want
a constructor or accessors for several of them. It shows a picker of the real fields and needs
jdtls to be attached.

Debugging a `main` method or a test uses the same shared [DAP](#debugging-dap) keymaps
(`<F5>`, `<leader>b`, ...) once jdtls generates a run configuration.

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

## Docker

`dockerls` for `Dockerfile`, `docker_compose_language_service` for `docker-compose.yml`. hadolint
lints Dockerfiles (see [Linting](#linting)).

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
