#!/bin/bash
# Docker Desktop, with its own engine, Compose and Buildx; the Docker CLI comes from packages/apt.txt. It is installed
# from a downloaded .deb, not a repository, so APT never upgrades it: `make update` does. Each download is checked
# against the checksums.txt Docker publishes next to it. That checksum comes from the same server as the file, so a
# build is also only installed once it is RELEASE_MIN_AGE_DAYS old (see lib.sh). The update feed only lists the newest
# build: until it is old enough, the installed build is kept, and a machine without Docker Desktop waits for it.
# `docker` commands go to Docker Desktop (the desktop-linux context), which does not start at login and opens in the
# tray without its Dashboard.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Docker Desktop"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

BASE_URL="https://desktop.docker.com/linux/main/amd64"
SETTINGS="$HOME/.docker/desktop/settings-store.json"

# Print "<build> <published, in seconds since 1970> <SHA-256>" for the newest build in the update feed
latest_build() {
  local feed build published checksum
  feed="$(curl -fsSL "$BASE_URL/appcast.xml")"
  # The feed links each build as .../amd64/<build>/docker-desktop-amd64.deb, after its <pubDate>
  build="$(grep -oE 'amd64/[0-9]+/docker-desktop-amd64\.deb' <<< "$feed" | cut -d/ -f2 | sort -n | tail -1)"
  [ -n "$build" ] || { echo "No build found in the Docker Desktop update feed" >&2; return 1; }
  published="$(grep -oE '<pubDate>[^<]+' <<< "$feed" | head -1 | cut -d'>' -f2)"
  if [ -z "$published" ] || ! published="$(date -d "$published" +%s)"; then
    echo "No publication date for build $build in the Docker Desktop update feed" >&2
    return 1
  fi
  checksum="$(curl -fsSL "$BASE_URL/$build/checksums.txt" | awk '$2 == "*docker-desktop-amd64.deb" { print $1 }')"
  [ -n "$checksum" ] || { echo "No checksum for docker-desktop-amd64.deb in build $build" >&2; return 1; }
  echo "$build $published $checksum"
}

# Print the installed build, which the package version ends in (e.g. 4.89.0-238018), or nothing
installed_build() {
  local version
  version="$(dpkg-query -W -f='${Version}' docker-desktop 2> /dev/null)" || return 0
  echo "${version##*-}"
}

install_latest() {
  local latest build published checksum installed age_days
  latest="$(latest_build)"
  read -r build published checksum <<< "$latest"
  installed="$(installed_build)"
  if [ -n "$installed" ] && [ "$build" -le "$installed" ]; then
    echo "Docker Desktop is up to date (build $installed)"
    return 0
  fi
  age_days="$((($(date +%s) - published) / 86400))"
  if [ "$published" -gt "$(release_cutoff)" ]; then
    if [ -n "$installed" ]; then
      echo "Docker Desktop build $build is $age_days days old; keeping build $installed until it is" \
        "$RELEASE_MIN_AGE_DAYS days old"
      return 0
    fi
    echo "Docker Desktop build $build, the only one Docker offers, is $age_days days old. Run this again once it" \
      "is $RELEASE_MIN_AGE_DAYS days old, or now with RELEASE_MIN_AGE_DAYS=0 to install it anyway." >&2
    return 1
  fi
  install_deb "$BASE_URL/$build/docker-desktop-amd64.deb" "$checksum"
}

on_install() {
  install_latest
  # Send docker commands to Docker Desktop rather than to Docker Engine's root-owned socket
  if ! docker context inspect desktop-linux > /dev/null 2>&1; then
    docker context create desktop-linux --description "Docker Desktop" \
      --docker "host=unix://$HOME/.docker/desktop/docker.sock"
  fi
  docker context use desktop-linux
  # Do not start at login: disable the systemd unit, and Docker Desktop's own "start when you sign in" setting, which
  # would enable the unit again. When it is started, it opens in the tray without the Dashboard.
  systemctl --user disable docker-desktop
  mkdir -p "$(dirname "$SETTINGS")"
  [ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  jq '.AutoStart = false | .OpenUIOnStartupDisabled = true' "$SETTINGS" > "$SETTINGS.new"
  mv "$SETTINGS.new" "$SETTINGS"
}

on_update() {
  [ -n "$(installed_build)" ] || { echo "Docker Desktop is not installed, skipping"; return; }
  install_latest
}

# The newest build, for the source check. `check` runs it as a condition, where `set -e` does not apply, so a failure
# is returned by hand.
latest_build_found() {
  local latest build published checksum
  latest="$(latest_build)" || return 1
  read -r build published checksum <<< "$latest"
  echo "build $build, published $((($(date +%s) - published) / 86400)) days ago (sha256:$checksum)"
}

on_sources() {
  check "the newest build in the update feed, and its checksum" latest_build_found
}

context_is_desktop() { [ "$(docker context show 2> /dev/null)" = desktop-linux ]; }
not_started_at_login() { [ "$(systemctl --user is-enabled docker-desktop 2> /dev/null)" != enabled ]; }
settings_applied() { jq -e '.OpenUIOnStartupDisabled == true and .AutoStart == false' "$SETTINGS"; }

on_doctor() {
  check "docker uses Docker Desktop (desktop-linux context)" context_is_desktop
  check "Docker Desktop does not start at login" not_started_at_login
  check "Docker Desktop starts in the tray, without the Dashboard, and not at login" settings_applied
}

on_tracked() {
  echo "apt:docker-desktop"
}

component_main "$@"
