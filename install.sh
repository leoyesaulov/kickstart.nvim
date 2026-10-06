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
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing tree-sitter-cli via Homebrew (required to compile parsers on Nvim 0.12+)..."
    brew install tree-sitter
  else
    echo "WARNING tree-sitter CLI not found and neither pacman nor brew is available." >&2
    echo "        Install it via your package manager (not npm — upstream warns" >&2
    echo "        the npm package is a mismatched build), then run :TSUpdate in Nvim." >&2
  fi
}

ensure_nerd_font() {
  echo "Installing a Nerd Font (JetBrainsMono) so icons render (init.lua sets have_nerd_font=true)..."
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed ttf-jetbrains-mono-nerd
  elif command -v brew >/dev/null 2>&1; then
    brew install --cask font-jetbrains-mono-nerd-font || {
      echo "WARNING font-jetbrains-mono-nerd-font cask not found — try 'brew tap homebrew/cask-fonts' first on older brew versions." >&2
    }
  else
    echo "WARNING Neither pacman nor brew found — install a Nerd Font manually from https://www.nerdfonts.com/ and select it in your terminal." >&2
  fi
}

ensure_lazygit() {
  if command -v lazygit >/dev/null 2>&1; then
    echo "OK      lazygit already installed ($(command -v lazygit))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing lazygit via pacman..."
    sudo pacman -S --needed lazygit
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing lazygit via Homebrew..."
    brew install lazygit
  else
    echo "WARNING lazygit not found and neither pacman nor brew is available." >&2
  fi
}

ensure_jdk() {
  if command -v javac >/dev/null 2>&1; then
    echo "OK      JDK already installed ($(command -v javac))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing jdk-openjdk via pacman (needed for Java LSP/debugging, jdtls)..."
    sudo pacman -S --needed jdk-openjdk
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing openjdk via Homebrew (needed for Java LSP/debugging, jdtls)..."
    brew install openjdk
    echo "NOTE    brew's openjdk is keg-only — follow its printed caveat to add it to PATH/JAVA_HOME." >&2
  else
    echo "WARNING JDK not found and neither pacman nor brew is available." >&2
  fi
}

ensure_tex_distribution() {
  if command -v latexmk >/dev/null 2>&1; then
    echo "OK      latexmk already installed ($(command -v latexmk))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing texlive-basic + texlive-latexextra via pacman (needed for vimtex/latexmk)..."
    sudo pacman -S --needed texlive-basic texlive-latexextra
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing basictex via Homebrew (lightweight TeX distro, needed for vimtex/latexmk)..."
    brew install --cask basictex
    if command -v tlmgr >/dev/null 2>&1; then
      sudo tlmgr update --self
      sudo tlmgr install latexmk
    else
      echo "NOTE    Open a new shell so tlmgr is on PATH, then run: sudo tlmgr install latexmk" >&2
    fi
  else
    echo "WARNING No TeX distribution found and neither pacman nor brew is available." >&2
  fi
}

ensure_pdf_viewer() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "OK      macOS: Preview.app works for viewing (no live forward-search)."
    echo "        For vimtex forward-search, optionally: brew install --cask skim"
    return
  fi

  if command -v zathura >/dev/null 2>&1; then
    echo "OK      zathura already installed ($(command -v zathura))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing zathura via pacman (PDF viewer with vimtex forward-search support)..."
    sudo pacman -S --needed zathura zathura-pdf-mupdf
  else
    echo "WARNING zathura not found and pacman is not available." >&2
  fi
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}"

ensure_tree_sitter_cli
ensure_nerd_font
ensure_lazygit
ensure_jdk
ensure_tex_distribution
ensure_pdf_viewer

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
