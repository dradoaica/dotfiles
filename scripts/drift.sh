#!/bin/bash
# Report what is installed on this machine but not listed in packages/, so a fresh install would miss it.
# Add each one to the matching list in packages/, or to packages/ignore.txt to stop reporting it.
# Covers APT packages you installed (not the ones Ubuntu installed), snaps, Flatpak apps and Homebrew.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# Print "<manager>:<name>" for everything tracked in packages/
tracked() {
  read_list apt.txt | sed 's/^/apt:/'
  printf 'apt:%s\n' "${PREREQUISITES[@]}"
  # The packages github-debs.sh installs, and Docker Desktop
  read_list github-debs.txt | awk '{ print "apt:" $2 }'
  echo "apt:docker-desktop"
  read_list snap.txt | awk '{ print "snap:" $1 }'
  read_list flatpak.txt | sed 's/^/flatpak:/'
  read_list brew.txt | sed -E 's/^--cask[[:space:]]+//; s/^/brew:/'
}

# Print the packages read from stdin that Ubuntu's own archive provides
from_ubuntu_archive() {
  local packages
  mapfile -t packages
  [ "${#packages[@]}" -gt 0 ] || return 0
  apt-cache policy "${packages[@]}" | awk '
    /^[^ ]/ { package = substr($0, 1, length($0) - 1) }
    /(archive|security|ports)\.ubuntu\.com/ && package != printed { print package; printed = package }'
}

# Print the installed metapackages that make up Ubuntu itself, e.g. ubuntu-desktop-minimal
ubuntu_metapackages() {
  dpkg-query -W -f='${db:Status-Status} ${Package}\n' 'ubuntu-*' 2> /dev/null \
    | awk '$1 == "installed" { print $2 }' \
    | grep -E '^ubuntu-(minimal|standard|desktop|desktop-minimal|restricted-addons)$' || true
}

# ubuntu_installed <manual packages>: print the ones among them that Ubuntu installed itself
ubuntu_installed() {
  local manual="$1" metapackages
  # Essential, or of priority required or important, and from Ubuntu's archive, since third-party packages can
  # claim any priority
  comm -12 <(echo "$manual") <(dpkg-query -W -f='${Package} ${Priority} ${Essential}\n' \
    | awk '$2 == "required" || $2 == "important" || $3 == "yes" { print $1 }' | sort -u) \
    | from_ubuntu_archive
  # What Ubuntu's metapackages depend on or recommend
  mapfile -t metapackages < <(ubuntu_metapackages)
  if [ "${#metapackages[@]}" -gt 0 ]; then
    apt-cache depends --no-pre-depends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances \
      "${metapackages[@]}" | awk '/(Depends|Recommends):/ { gsub(/[<>]/, "", $2); print $2 }'
  fi
}

# APT packages that were installed on request, minus the ones Ubuntu installed itself
apt_installed() {
  local manual
  # Without the architecture suffix of foreign packages, e.g. steam:i386
  manual="$(apt-mark showmanual | sed 's/:[a-z0-9]*$//' | sort -u)"
  comm -23 <(echo "$manual") <(ubuntu_installed "$manual" | sort -u) | sed 's/^/apt:/'
}

# Print "<manager>:<name>" for everything installed that drift can compare
installed() {
  apt_installed
  if command -v snap > /dev/null; then
    snap list | awk 'NR > 1 { print "snap:" $1 }'
  fi
  if command -v flatpak > /dev/null; then
    flatpak list --app --columns=application | sed 's/^/flatpak:/'
  fi
  if load_homebrew; then
    { brew leaves --installed-on-request; brew list --cask; } | sed 's/^/brew:/'
  fi
}

ignored='^('"$(read_list ignore.txt | paste -sd'|')"')$'
mapfile -t untracked < <(comm -23 <(installed | sort -u) <(tracked | sort -u) | grep -vE "$ignored" || true)

if [ "${#untracked[@]}" -eq 0 ]; then
  echo "Everything installed is listed in packages/"
  exit 0
fi
echo "Installed but not listed in packages/ (add to the matching list, or to packages/ignore.txt):"
printf '  %s\n' "${untracked[@]}"
