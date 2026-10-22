#!/bin/bash
# Set up a fresh machine from nothing: clone (or update) this repository, then run the installer.
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/dradoaica/dotfiles/main/scripts/bootstrap.sh)
# Set DOTFILES_DIR to clone somewhere other than ~/Projects/dotfiles.

set -euo pipefail

REPO_URL="https://github.com/dradoaica/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Projects/dotfiles}"

if ! command -v git > /dev/null; then
  sudo apt-get update
  sudo apt-get install -y git
fi

if [ -d "$DOTFILES_DIR/.git" ]; then
  git -C "$DOTFILES_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

exec bash "$DOTFILES_DIR/scripts/install.sh"
