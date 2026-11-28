#!/bin/bash
# Homebrew, and the formulae and casks in packages/brew.txt. Homebrew is installed once, from the newest commit of its
# installer that is at least RELEASE_MIN_AGE_DAYS old (see lib.sh), not from the branch: the installer runs with the
# sudo that packages.sh has already unlocked. After that, `brew update` keeps it up to date.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="Homebrew"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

installer_url() {
  local commit
  commit="$(github_commit Homebrew/install install.sh)" || return 1
  [ -n "$commit" ] || { echo "Found no commit of the Homebrew installer to install from" >&2; return 1; }
  echo "https://raw.githubusercontent.com/Homebrew/install/$commit/install.sh"
}

on_install() {
  if ! load_homebrew; then
    local url
    url="$(installer_url)"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$url")"
    load_homebrew
  fi
  install_each brew.txt brew install
}

on_update() {
  load_homebrew || { echo "Homebrew is not installed, skipping"; return; }
  brew update
  brew upgrade
  brew cleanup
}

installer_found() {
  local url
  url="$(installer_url)" || return 1
  url_exists "$url"
}

# exists <line of brew.txt>: a cask, a formula from a tap (owner/tap/name) or a core formula
exists() {
  case "$1" in
    "--cask "*) url_found "https://formulae.brew.sh/api/cask/${1#--cask }.json" ;;
    */*/*)
      local owner="${1%%/*}" name="${1##*/}" tap="${1#*/}"
      url_found "https://raw.githubusercontent.com/$owner/homebrew-${tap%%/*}/HEAD/Formula/$name.rb"
      ;;
    *) url_found "https://formulae.brew.sh/api/formula/$1.json" ;;
  esac
}

on_sources() {
  check "the installer, at the commit it would be installed from" installer_found
  local entry
  while read -r entry; do
    check "$entry" exists "$entry"
  done < <(read_list brew.txt)
}

installed_names() { brew list -1 --formula && brew list -1 --cask; }

on_doctor() {
  load_homebrew || true
  check "every formula and cask in packages/brew.txt is installed" all_installed brew.txt installed_names
}

on_tracked() {
  read_list brew.txt | sed -E 's/^--cask[[:space:]]+//; s/^/brew:/'
}

component_main "$@"
