#!/bin/bash
# Wayland Scroll Factor's settings: slower touchpad scrolling, from the next login. The app itself comes from
# packages/github-debs.txt; remove this component too if you remove it from there.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Wayland Scroll Factor"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  wsf set --scroll-vertical 0.30 --scroll-horizontal 0.30 --pinch-zoom 1.00 --pinch-rotate 1.00
  wsf enable
}

enabled() { wsf status | grep -q '^enabled: yes'; }

on_doctor() {
  check "Wayland Scroll Factor is enabled" enabled
}

component_main "$@"
