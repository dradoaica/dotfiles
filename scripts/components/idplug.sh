#!/bin/bash
# IDplug Classic, IDEMIA's middleware for the Romanian electronic identity card (CEI), with its PKCS#11 module
# registered in Chrome and the Firefox snap, so websites such as hub.mai.gov.ro can see the card's certificates; the
# package only makes them visible to IDplug Manager. MAI publishes neither a checksum nor an update feed, so the
# download is pinned to the file it served for VERSION: when MAI replaces it, the checksum fails and the pin below
# needs updating.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Electronic ID (IDplug Classic)"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

URL="https://hub.mai.gov.ro/cei/info/descarca-middleware?versiune=450linux"
VERSION="4.5.0.487"
SHA256="4d084400dcd80535fcbf5e2b3194e996039ec96199241573b1d63af7bfeb0484"
MODULE_NAME="IDEMIA IDPlug"
MODULE_LIBRARY="/usr/lib/idplugclassic/libidplug-pkcs11.so"
# Chrome's certificate and security module database
NSS_DB="sql:$HOME/.pki/nssdb"
# The Firefox snap cannot see /usr/lib, and may only load libraries from its own folder in ~/snap
FIREFOX_LIBRARY="$HOME/snap/firefox/common/pkcs11/${MODULE_LIBRARY##*/}"
FIREFOX_POLICIES=/etc/firefox/policies/policies.json

install_pinned() {
  local installed
  installed="$(dpkg-query -W -f='${Version}' idplugclassic 2> /dev/null || true)"
  if [ -n "$installed" ] && ! dpkg --compare-versions "$installed" lt "$VERSION"; then
    echo "IDplug Classic is up to date ($installed)"
  else
    install_deb "$URL" "$SHA256"
  fi
}

# -rawlist reads the registration without loading the module: -list <name> fails while the card is not inserted
chrome_has_module() {
  local modules
  modules="$(modutil -dbdir "$NSS_DB" -rawlist)" || return 1
  grep -qF "library=\"$MODULE_LIBRARY\" name=\"$MODULE_NAME\"" <<< "$modules"
}

register_with_chrome() {
  # Chrome creates the database on its first start; create it now if Chrome has not run yet
  if [ ! -f "$HOME/.pki/nssdb/cert9.db" ]; then
    mkdir -p "$HOME/.pki/nssdb"
    chmod 700 "$HOME/.pki" "$HOME/.pki/nssdb"
    certutil -d "$NSS_DB" -N --empty-password
  fi
  if chrome_has_module; then
    echo "Chrome already has the $MODULE_NAME module"
  else
    # -force skips the prompt to close the browser; a running Chrome sees the module after a restart
    modutil -dbdir "$NSS_DB" -add "$MODULE_NAME" -libfile "$MODULE_LIBRARY" -force
  fi
}

# Firefox loads the module through a policy, which also covers profiles that do not exist yet, from its next start.
# The module's own dependencies come from the snap's runtime.
register_with_firefox() {
  snap list firefox > /dev/null 2>&1 || return 0
  cmp -s "$MODULE_LIBRARY" "$FIREFOX_LIBRARY" || install -D -m 0644 "$MODULE_LIBRARY" "$FIREFOX_LIBRARY"
  # Lets Firefox reach the card reader through pcscd
  sudo snap connect firefox:pcscd
  local current='{}'
  [ ! -s "$FIREFOX_POLICIES" ] || current="$(cat "$FIREFOX_POLICIES")"
  jq --arg name "$MODULE_NAME" --arg path "$FIREFOX_LIBRARY" '.policies.SecurityDevices.Add[$name] = $path' \
    <<< "$current" | sudo install -D -m 0644 /dev/stdin "$FIREFOX_POLICIES"
}

on_install() {
  install_pinned
  register_with_chrome
  register_with_firefox
}

# Installs the pinned version when it changes, and keeps the browsers' copy of the module current
on_update() {
  deb_installed idplugclassic || { echo "IDplug Classic is not installed, skipping"; return; }
  on_install
}

# The package is built for Ubuntu 24.04, so also check that this release still offers everything it depends on. The
# simulation lists every package it would install; show its output only when it fails, without that list.
download_installs() {
  local dir simulation status=0
  dir="$(mktemp -d)"
  download_verified "$URL" "$SHA256" "$dir/idplugclassic.deb" || { rm -rf "$dir"; return 1; }
  if simulation="$(apt-get install --simulate "$dir/idplugclassic.deb" 2>&1)"; then
    echo "IDplug Classic $(dpkg-deb -f "$dir/idplugclassic.deb" Version) installs on this release"
  else
    grep -vE '^(Inst|Conf) |^NOTE: This is only a simulation|^ +(apt-get needs root|Keep also in mind|so don.t)' \
      <<< "$simulation" >&2
    status=1
  fi
  rm -rf "$dir"
  return "$status"
}

on_sources() {
  check "the download is the pinned file, and installs on this release" download_installs
}

firefox_has_module() {
  snap list firefox > /dev/null 2>&1 || return 0
  cmp "$MODULE_LIBRARY" "$FIREFOX_LIBRARY" || return 1
  jq -e --arg name "$MODULE_NAME" --arg path "$FIREFOX_LIBRARY" '.policies.SecurityDevices.Add[$name] == $path' \
    "$FIREFOX_POLICIES" || return 1
  snap connections firefox | awk '$2 == "firefox:pcscd" && $3 != "-" { found = 1 } END { exit !found }' \
    || { echo "firefox:pcscd is not connected" >&2; return 1; }
}

on_doctor() {
  check "IDplug Classic is installed" deb_installed idplugclassic
  check "Chrome can use the electronic ID card ($MODULE_NAME module)" chrome_has_module
  check "Firefox can use the electronic ID card (module, policy and pcscd connection)" firefox_has_module
}

on_tracked() {
  echo "apt:idplugclassic"
}

component_main "$@"
