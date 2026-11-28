#!/bin/bash
# The udev rules in system/udev/, which cannot be symlinked from home/: they go to /etc/udev/rules.d/.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="udev rules"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  sudo install -m 0644 -t /etc/udev/rules.d "$ROOT_DIR"/system/udev/*.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger --subsystem-match=hidraw
}

rules_installed() {
  local rule
  for rule in "$ROOT_DIR"/system/udev/*.rules; do
    cmp -s "$rule" "/etc/udev/rules.d/${rule##*/}" || return 1
  done
}

# Rules in /etc/udev/rules.d/ that neither this repository, a package nor snapd installed, which a fresh install
# would not have
no_unmanaged_rules() {
  local rule unmanaged=0
  for rule in /etc/udev/rules.d/*.rules; do
    [ -e "$rule" ] || continue
    case "${rule##*/}" in 70-snap.*) continue ;; esac
    if [ -e "$ROOT_DIR/system/udev/${rule##*/}" ] || dpkg -S "$rule" > /dev/null 2>&1; then
      continue
    fi
    echo "not managed: $rule" >&2
    unmanaged=1
  done
  return "$unmanaged"
}

on_doctor() {
  check "the udev rules in system/udev/ are installed" rules_installed
  check "every udev rule in /etc/udev/rules.d/ comes from system/udev/, a package or snapd" no_unmanaged_rules
}

component_main "$@"
