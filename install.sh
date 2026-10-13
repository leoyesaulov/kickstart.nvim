#!/usr/bin/env bash
# Symlinks this repo's init.lua and lua/ into Neovim's config directory,
# regardless of where the repo itself is checked out.
#
# Usage: ./install.sh
# Safe to re-run: already-correct symlinks are left alone, anything else
# in the way is backed up (never deleted) before linking.
set -euo pipefail

# ensure_pkg <command> <pacman packages> <brew formula> <reason>
# Installs the package(s) providing <command> unless it's already on PATH.
# <pacman packages> may list several space-separated packages.
ensure_pkg() {
  local cmd="$1" pacman_pkgs="$2" brew_pkg="$3" reason="$4"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK      $cmd already installed ($(command -v "$cmd"))"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing $pacman_pkgs via pacman ($reason)..."
    # shellcheck disable=SC2086 # intentional word-splitting of the package list
    sudo pacman -S --needed $pacman_pkgs
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing $brew_pkg via Homebrew ($reason)..."
    brew install "$brew_pkg"
  else
    echo "WARNING $cmd not found and neither pacman nor brew is available ($reason)." >&2
  fi
}

ensure_build_tools() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # Homebrew's installer already pulls in the Xcode Command Line Tools (make, cc, python3, unzip).
    if xcode-select -p >/dev/null 2>&1; then
      echo "OK      Xcode Command Line Tools installed"
    else
      echo "WARNING Xcode Command Line Tools missing — run 'xcode-select --install', then re-run this script." >&2
    fi
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing base-devel, unzip, python via pacman (plugin builds, Mason unpacking, debugpy)..."
    sudo pacman -S --needed base-devel unzip python
  else
    echo "WARNING pacman not found — make sure make, a C compiler, unzip and python3 are installed." >&2
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

ensure_jdk() {
  # macOS ships stub /usr/bin/java{,c} that exist on PATH but fail with "Unable to locate a Java
  # Runtime" — so check that javac actually runs, not just that it's on PATH.
  if javac -version >/dev/null 2>&1 || { [[ "$(uname)" == "Darwin" ]] && /usr/libexec/java_home >/dev/null 2>&1; }; then
    echo "OK      JDK already installed"
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "Installing jdk-openjdk via pacman (needed for Java LSP/debugging, jdtls)..."
    sudo pacman -S --needed jdk-openjdk
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing openjdk via Homebrew (needed for Java LSP/debugging, jdtls)..."
    brew install openjdk
    # brew's openjdk is keg-only; link it where java_home and the /usr/bin stubs look for JDKs.
    echo "Linking openjdk into /Library/Java/JavaVirtualMachines (needs sudo)..."
    sudo ln -sfn "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
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
    local tlmgr=/Library/TeX/texbin/tlmgr
    if [[ ! -x "$tlmgr" ]]; then
      echo "Installing basictex via Homebrew (lightweight TeX distro, needed for vimtex/latexmk)..."
      brew install --cask basictex
    fi
    # Call tlmgr by full path: /Library/TeX/texbin isn't on PATH until a new shell starts.
    if [[ -x "$tlmgr" ]]; then
      echo "Installing latexmk via tlmgr..."
      sudo "$tlmgr" update --self
      sudo "$tlmgr" install latexmk
      echo "NOTE    Open a new shell so /Library/TeX/texbin (latexmk) is on PATH." >&2
    else
      echo "WARNING tlmgr not found at $tlmgr — install latexmk manually: sudo tlmgr install latexmk" >&2
    fi
  else
    echo "WARNING No TeX distribution found and neither pacman nor brew is available." >&2
  fi
}

ensure_pdf_viewer() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # latex.lua sets vimtex_view_method = 'skim' on macOS.
    if [[ -d /Applications/Skim.app ]]; then
      echo "OK      Skim already installed"
    else
      echo "Installing Skim via Homebrew (PDF viewer with vimtex forward-search support)..."
      brew install --cask skim
    fi
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

ensure_build_tools
ensure_pkg nvim neovim neovim "the editor itself"
ensure_pkg rg ripgrep ripgrep "Telescope live grep"
ensure_pkg fd fd fd "needed by venv-selector.nvim to locate virtualenvs"
# Not npm's tree-sitter-cli — upstream warns it's a mismatched build. On brew, the plain
# 'tree-sitter' formula is only the library; the CLI is 'tree-sitter-cli'.
ensure_pkg tree-sitter tree-sitter-cli tree-sitter-cli "required to compile parsers on Nvim 0.12+"
ensure_pkg npm "nodejs npm" node "Mason installs pyright, ts_ls, eslint, prettier, etc. via npm"
ensure_pkg go go go "Mason installs gopls and delve via go"
ensure_jdk
ensure_pkg lazygit lazygit lazygit "LazyGit integration"
ensure_nerd_font
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
echo "Next: open nvim and let Lazy + Mason finish installing (:Lazy, :Mason), then run :checkhealth."
