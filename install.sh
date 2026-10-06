#!/usr/bin/env bash
# Symlinks this repo's init.lua and lua/ into Neovim's config directory,
# regardless of where the repo itself is checked out.
#
# Usage: ./install.sh
# Safe to re-run: already-correct symlinks are left alone, anything else
# in the way is backed up (never deleted) before linking.
set -euo pipefail

ensure_tree_sitter_cli() {
  if command -v tree-sitter >/dev/null 2>&1; then
    echo "OK      tree-sitter CLI already installed ($(command -v tree-sitter))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing tree-sitter-cli via pacman (required to compile parsers on Nvim 0.12+)..."
    sudo pacman -S --needed tree-sitter-cli
  else
    echo "WARNING tree-sitter CLI not found and pacman isn't available." >&2
    echo "        Install it via your package manager (not npm — upstream warns" >&2
    echo "        the npm package is a mismatched build), then run :TSUpdate in Nvim." >&2
  fi
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}"

ensure_tree_sitter_cli

if [[ "$repo_dir" == "$config_dir" ]]; then
  echo "Repo is already checked out at $config_dir — nothing to link."
  exit 0
fi

mkdir -p "$config_dir"

link() {
  local src="$repo_dir/$1" dest="$config_dir/$1"

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "OK      $dest -> $src (already linked)"
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "BACKED UP  $dest -> $backup"
  fi

  ln -s "$src" "$dest"
  echo "LINKED  $dest -> $src"
}

link init.lua
link lua

echo "Done. Config dir: $config_dir"
