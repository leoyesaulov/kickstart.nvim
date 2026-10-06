# CLAUDE.md

Repo-specific rules for Claude Code / AI assistants working in this repo.

## Keybinding changes

Whenever a keymap is added, removed, or changed — in `init.lua`, `lua/kickstart/plugins/*.lua`,
or `lua/custom/plugins/*.lua` — update BOTH of these together:

- `cheatsheet.md` — narrative, topic-grouped quick-reference guide
- `bindings.md` — flat table of every binding, sorted by key, for quick lookup/grep

Keep the "disabled" sections in both files accurate to which `require(...)` lines are actually
commented out in `init.lua`'s `lazy.setup { ... }` call — don't list a binding as active if its
plugin isn't loaded, and don't list it as disabled if it is.

## Installation process changes

Whenever the install process changes — dependencies, symlink targets, package manager commands,
supported tools — update all three install scripts together:

- `install.sh` — bash, the source of truth for all install/symlink logic
- `install.fish`
- `install.zsh`

`install.fish` and `install.zsh` are thin wrappers that `exec` into `install.sh`; keep them that
way — don't duplicate install logic into them.

All three must keep working on the latest Arch Linux release and the latest macOS release.
Arch uses `pacman`, macOS uses `brew`; detect the platform and branch accordingly. Don't add
support for other distros/package managers inside these scripts (README's "Install Recipes"
section covers those manually).
