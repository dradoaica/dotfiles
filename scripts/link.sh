#!/bin/bash
# Manage the symlinks from the packages in home/ into $HOME with GNU Stow.
# Usage: link.sh [--check | --unlink] [package...]   (default: every package in home/)
#   (no option)  link the packages; existing files are moved to ~/.dotfiles-backup/<timestamp>/ first
#   --check      report files that are not linked yet, without changing anything
#   --unlink     remove the links (the files stay in the repository)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
PACKAGES_DIR="$ROOT_DIR/home"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

mode="link"
case "${1:-}" in
  --check) mode="check"; shift ;;
  --unlink) mode="unlink"; shift ;;
  -*) echo "Usage: $(basename "$0") [--check | --unlink] [package...]" >&2; exit 1 ;;
esac

if [ "$mode" != check ] && ! command -v stow > /dev/null; then
  sudo apt-get install -y stow
fi

if [ $# -gt 0 ]; then
  packages=("$@")
else
  mapfile -t packages < <(find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi

# Print "<file in repo>\t<relative path>" for every file in a package
package_files() {
  find "$PACKAGES_DIR/$1" -type f -printf "%p\t%P\n" | sort
}

is_linked() {
  [ -L "$2" ] && [ "$(readlink -f "$2")" = "$(readlink -f "$1")" ]
}

# Print the symlinks in $HOME that point into home/ at a file that is no longer there, because it was removed from
# the repository. Stow only knows about the files that are still there, so it never removes these.
# Skips caches, snaps and the trash, which never hold dotfiles.
stale_links() {
  find "$HOME" -xdev \( -path "$HOME/.cache" -o -path "$HOME/snap" -o -path "$HOME/.local/share/Trash" \) -prune \
    -o -xtype l -lname "*${PACKAGES_DIR#"$HOME"/}/*" -print
}

backed_up=false
problems=0
while read -r link; do
  [ -n "$link" ] || continue
  case "$mode" in
    link) rm "$link"; echo "Removed ~/${link#"$HOME"/}, which points to a file no longer in the repository" ;;
    check)
      echo "stale     ~/${link#"$HOME"/} (points to a file no longer in the repository)"
      problems=$((problems + 1))
      ;;
  esac
done < <(stale_links)
for package in "${packages[@]}"; do
  [ -d "$PACKAGES_DIR/$package" ] || { echo "Unknown package: $package" >&2; exit 1; }
  case "$mode" in
    link)
      # Move aside anything at a target path that is not already our symlink
      while IFS=$'\t' read -r file relative; do
        target="$HOME/$relative"
        if { [ -e "$target" ] || [ -L "$target" ]; } && ! is_linked "$file" "$target"; then
          mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
          mv "$target" "$BACKUP_DIR/$relative"
          echo "Backed up ~/$relative"
          backed_up=true
        fi
      done < <(package_files "$package")
      # --no-folding links individual files, so apps never write their own files into the repo
      stow --no-folding --dir "$PACKAGES_DIR" --target "$HOME" --restow "$package"
      echo "Linked $package"
      ;;
    unlink)
      stow --no-folding --dir "$PACKAGES_DIR" --target "$HOME" --delete "$package"
      echo "Unlinked $package"
      ;;
    check)
      while IFS=$'\t' read -r file relative; do
        target="$HOME/$relative"
        if is_linked "$file" "$target"; then
          continue
        elif [ -e "$target" ] || [ -L "$target" ]; then
          echo "conflict  ~/$relative (exists but is not linked to the repository)"
        else
          echo "missing   ~/$relative"
        fi
        problems=$((problems + 1))
      done < <(package_files "$package")
      ;;
  esac
done

if [ "$backed_up" = true ]; then
  echo "Replaced files were saved in $BACKUP_DIR"
fi
if [ "$mode" = check ]; then
  if [ "$problems" -gt 0 ]; then
    echo "$problems file(s) not linked or stale; run scripts/link.sh to fix" >&2
    exit 1
  fi
  echo "All files are linked"
fi
