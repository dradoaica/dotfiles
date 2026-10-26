#!/bin/bash
# Check that this machine is still set up the way the installer left it, without changing anything.
# Exits with an error if any check fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

failures=0
# check <description> <command...>: run the command quietly and report whether it succeeded
check() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "ok    $description"
  else
    echo "FAIL  $description"
    failures=$((failures + 1))
  fi
}

installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
not_installed() { ! installed "$1"; }
user_service_enabled() { [ "$(systemctl --user is-enabled "$1" 2>/dev/null)" = enabled ]; }
service_disabled() { [ "$(systemctl is-enabled "$1" 2>/dev/null)" != enabled ]; }
service_running() { systemctl is-active --quiet "$1"; }
docker_context_is_desktop() { [ "$(docker context show 2>/dev/null)" = desktop-linux ]; }
docker_dashboard_closed_at_start() {
  jq -e '.OpenUIOnStartupDisabled == true and .AutoStart == true' "$HOME/.docker/desktop/settings-store.json"
}
microk8s_not_started_at_boot() {
  local services
  services="$(snap services microk8s)" || return 1
  ! awk 'NR > 1 { print $2 }' <<< "$services" | grep -qx enabled
}
kubeconfig_private() { [ ! -e "$HOME/.kube/config" ] || [ "$(stat -c '%a' "$HOME/.kube/config")" = 600 ]; }
wsf_enabled() { wsf status | grep -q '^enabled: yes'; }
extensions_enabled() {
  local enabled uuid
  enabled="$(gnome-extensions list --enabled)"
  while read -r uuid; do
    grep -qxF "$uuid" <<< "$enabled" || { echo "not enabled: $uuid" >&2; return 1; }
  done < <(grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/gnome/extensions.txt")
}

echo "== Dotfiles"
check "every dotfile is linked" bash "$SCRIPT_DIR/link.sh" --check

echo "== Docker"
check "docker uses Docker Desktop (desktop-linux context)" docker_context_is_desktop
check "Docker Desktop starts at login" user_service_enabled docker-desktop
check "Docker Desktop starts minimised, without the Dashboard" docker_dashboard_closed_at_start
check "Docker Engine does not start at boot" service_disabled docker.service
check "containerd does not start at boot" service_disabled containerd.service

echo "== Kubernetes"
check "MicroK8s does not start at boot" microk8s_not_started_at_boot
# shellcheck disable=SC2088 # the ~ is part of the message
check "~/.kube/config is readable only by you" kubeconfig_private

echo "== Security"
check "ClamAV virus definitions are kept up to date (clamav-freshclam)" service_running clamav-freshclam
check "GitHub CLI is logged in" gh auth status

echo "== Apps"
check "OpenLogi is installed" installed openlogi
check "Solaar is not installed" not_installed solaar
check "balenaEtcher is installed" installed balena-etcher
check "Wayland Scroll Factor is installed and enabled" wsf_enabled

echo "== GNOME"
check "every extension in gnome/extensions.txt is enabled" extensions_enabled

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "Everything checks out"
