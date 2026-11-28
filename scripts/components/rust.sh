#!/bin/bash
# The stable Rust toolchain, installed with rustup (a snap, from packages/snap.txt).
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Rust"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  rustup install stable
}

on_update() {
  command -v rustup > /dev/null || { echo "rustup is not installed, skipping"; return; }
  rustup update
}

component_main "$@"
