#!/bin/bash
# The apps published as .deb files on GitHub releases, listed in packages/github-debs.txt, installed or upgraded from
# their newest release that is at least RELEASE_MIN_AGE_DAYS old (see lib.sh). Uses the GitHub API directly, so it
# works before `gh auth login`. Each download is checked against the SHA-256 digest GitHub publishes for it, and an
# asset without one is not installed. That digest comes from the same place as the file, so it does not help when a
# maintainer's account is taken over and a release is replaced; the wait is for that.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="Apps from GitHub releases"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# release_asset <owner/repo> <regex>: print, as JSON, the version, name, URL and SHA-256 of the asset matching the
# regex in the newest release that is old enough
release_asset() {
  local release asset
  release="$(github_release "$1")" || return 1
  [ -n "$release" ] || { echo "$1 has no release that is at least $RELEASE_MIN_AGE_DAYS days old" >&2; return 1; }
  asset="$(jq -c --arg pattern "$2" '(.tag_name | ltrimstr("v")) as $version
    | [.assets[] | select(.name | test($pattern))][0] // empty
    | {version: $version, name, url: .browser_download_url, sha256: (.digest // "" | ltrimstr("sha256:"))}' \
    <<< "$release")"
  [ -n "$asset" ] || { echo "No asset matching $2 in the newest $1 release" >&2; return 1; }
  # GitHub publishes a digest for each release asset uploaded since mid-2025
  if [ -z "$(jq -r '.sha256' <<< "$asset")" ]; then
    echo "$1: $(jq -r '.name' <<< "$asset") has no SHA-256 digest to check it against" >&2
    return 1
  fi
  echo "$asset"
}

# install_latest <owner/repo> <package> <regex>
install_latest() {
  local asset version installed
  asset="$(release_asset "$1" "$3")"
  version="$(jq -r '.version' <<< "$asset")"
  installed="$(dpkg-query -W -f='${Version}' "$2" 2> /dev/null || true)"
  if [ -n "$installed" ] && ! dpkg --compare-versions "$installed" lt "$version"; then
    echo "$2 is up to date ($installed)"
    return 0
  fi
  install_deb "$(jq -r '.url' <<< "$asset")" "$(jq -r '.sha256' <<< "$asset")"
}

# Each app is a step of its own, so one broken release does not hold back the others
install_all() {
  local repo package pattern
  while read -r repo package pattern; do
    step "$package" install_latest "$repo" "$package" "$pattern" < /dev/null
  done < <(read_list github-debs.txt)
  [ "${#failed_steps[@]}" -eq 0 ]
}

on_install() {
  # OpenLogi replaces Solaar, and does not work while Solaar is installed: both drive the same Logitech devices
  if deb_installed solaar; then
    apt_get purge -y solaar
  fi
  install_all
  # Slow down touchpad scrolling on Wayland; takes effect after the next login
  wsf set --scroll-vertical 0.30 --scroll-horizontal 0.30 --pinch-zoom 1.00 --pinch-rotate 1.00
  wsf enable
}

on_update() {
  install_all
}

on_sources() {
  local repo package pattern
  while read -r repo package pattern; do
    check "$repo has a release with a .deb matching $pattern and its digest" release_asset "$repo" "$pattern"
  done < <(read_list github-debs.txt)
}

wsf_enabled() { wsf status | grep -q '^enabled: yes'; }

on_doctor() {
  local repo package
  while read -r repo package _; do
    check "$package from $repo is installed" deb_installed "$package"
  done < <(read_list github-debs.txt)
  check "Solaar is not installed (OpenLogi does not work with it)" deb_not_installed solaar
  check "Wayland Scroll Factor is enabled" wsf_enabled
}

on_tracked() {
  read_list github-debs.txt | awk '{ print "apt:" $2 }'
}

component_main "$@"
