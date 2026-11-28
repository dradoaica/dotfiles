#!/bin/bash
# JetBrains Toolbox, in /opt/jetbrains-toolbox. Installed once, since it updates itself, from the newest release that
# is at least RELEASE_MIN_AGE_DAYS old (see lib.sh), checked against the SHA-256 file JetBrains publishes next to it.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="JetBrains Toolbox"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

INSTALL_DIR=/opt/jetbrains-toolbox

# Print, as JSON, the Linux download (link and checksumLink) of the newest release that is old enough, or nothing.
# JetBrains dates its releases by day, and can publish two on the same day (e.g. 3.9.1 and 3.8.2), so the build
# number breaks the tie.
download() {
  curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&type=release" \
    | jq -c --argjson cutoff "$(release_cutoff)" '
      [.TBA[] | select((.date + "T00:00:00Z" | fromdateiso8601) <= $cutoff)]
      | sort_by(.date, (.build | split(".") | map(tonumber))) | last // empty | .downloads.linux'
}

on_install() {
  if [ -x "$INSTALL_DIR/bin/jetbrains-toolbox" ]; then
    echo "JetBrains Toolbox is already installed"
    return
  fi
  local release checksum archive
  release="$(download)"
  [ -n "$release" ] || { echo "Found no release that is at least $RELEASE_MIN_AGE_DAYS days old" >&2; return 1; }
  # "<hash> *<file name>"
  checksum="$(curl -fsSL "$(jq -r '.checksumLink' <<< "$release")" | awk '{ print $1 }')"
  archive="$(mktemp --suffix=.tar.gz)"
  # Expanded now: $archive is local, and gone by the time the trap runs
  # shellcheck disable=SC2064
  trap "rm -f '$archive'" EXIT
  download_verified "$(jq -r '.link' <<< "$release")" "$checksum" "$archive"
  sudo mkdir -p "$INSTALL_DIR"
  sudo tar -xzf "$archive" -C "$INSTALL_DIR" --strip-components=1
  sudo chmod +x "$INSTALL_DIR/bin/jetbrains-toolbox"
  # The first start registers its desktop entry and autostart
  "$INSTALL_DIR/bin/jetbrains-toolbox" &
  sleep 5
  pkill jetbrains-toolbox || true
}

has_download() {
  download | jq -e '(.link | strings) and (.checksumLink | strings)'
}

on_sources() {
  check "the download link and checksum of the release it would install" has_download
}

component_main "$@"
