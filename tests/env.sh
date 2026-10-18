#!/usr/bin/env bash
# Used by the Makefile targets: points every Neovim XDG dir into .tests/ so test runs never
# touch the real ~/.config/nvim or ~/.local/share/nvim, and plugins are cached between runs.
# Usage: tests/env.sh <command...>   (runs the command inside the sandbox env)
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$repo_dir/.tests"

# jupytext.nvim needs the `jupytext` CLI to open the .ipynb fixture. Borrow it from the real
# molten venv install.sh creates (read-only use), since the sandbox's data dir has none.
real_venv="${XDG_DATA_HOME:-$HOME/.local/share}/${NVIM_APPNAME:-nvim}/molten-venv"
if [[ -x "$real_venv/bin/jupytext" ]] && ! command -v jupytext >/dev/null 2>&1; then
  export PATH="$PATH:$real_venv/bin"
fi

mkdir -p "$sandbox/data" "$sandbox/state" "$sandbox/cache"
# The sandbox config dir links init.lua and lua/ back to the repo, but gets a *copy* of
# lazy-lock.json: lazy.nvim rewrites the lockfile in stdpath('config') whenever the installed
# plugin set differs, and a test run must never modify the tracked one.
config="$sandbox/config/nvim"
[[ -L "$config" ]] && rm "$config" # older layout: whole-repo symlink
mkdir -p "$config"
ln -sfn "$repo_dir/init.lua" "$config/init.lua"
ln -sfn "$repo_dir/lua" "$config/lua"
cp "$repo_dir/lazy-lock.json" "$config/lazy-lock.json"

export XDG_CONFIG_HOME="$sandbox/config"
export XDG_DATA_HOME="$sandbox/data"
export XDG_STATE_HOME="$sandbox/state"
export XDG_CACHE_HOME="$sandbox/cache"
export NVIM_APPNAME=nvim
export KICKSTART_REPO="$repo_dir"
# Image support depends on the terminal (see jupyter.lua); headless runs have none, and
# image.nvim would only complain that it can't query the terminal size.
unset KITTY_WINDOW_ID TERM_PROGRAM
export TERM=xterm-256color

cd "$repo_dir"
exec "$@"
