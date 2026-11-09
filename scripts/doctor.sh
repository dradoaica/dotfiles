#!/bin/bash
# Check that this machine is still set up the way the installer left it, without changing anything.
# Exits with an error if any check fails.

# No `set -e`: a check that fails must not stop the checks after it
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
not_installed() { ! installed "$1"; }
user_service_disabled() { [ "$(systemctl --user is-enabled "$1" 2>/dev/null)" != enabled ]; }
service_disabled() { [ "$(systemctl is-enabled "$1" 2>/dev/null)" != enabled ]; }
service_running() { systemctl is-active --quiet "$1"; }
docker_context_is_desktop() { [ "$(docker context show 2>/dev/null)" = desktop-linux ]; }
docker_desktop_settings() {
  jq -e '.OpenUIOnStartupDisabled == true and .AutoStart == false' "$HOME/.docker/desktop/settings-store.json"
}
microk8s_not_started_at_boot() {
  local services
  services="$(snap services microk8s)" || return 1
  ! awk 'NR > 1 { print $2 }' <<< "$services" | grep -qx enabled
}
kubeconfig_private() { [ ! -e "$HOME/.kube/config" ] || [ "$(stat -c '%a' "$HOME/.kube/config")" = 600 ]; }
chrome_has_idplug() { modutil -dbdir "sql:$HOME/.pki/nssdb" -list "IDEMIA IDPlug"; }
firefox_has_idplug() {
  local library="$HOME/snap/firefox/common/pkcs11/libidplug-pkcs11.so"
  ! snap list firefox > /dev/null 2>&1 && return
  cmp /usr/lib/idplugclassic/libidplug-pkcs11.so "$library" || return 1
  jq -e --arg path "$library" '.policies.SecurityDevices.Add["IDEMIA IDPlug"] == $path' \
    /etc/firefox/policies/policies.json || return 1
  snap connections firefox | awk '$2 == "firefox:pcscd" && $3 != "-" { found = 1 } END { exit !found }' \
    || { echo "firefox:pcscd is not connected" >&2; return 1; }
}
wsf_enabled() { wsf status | grep -q '^enabled: yes'; }
udev_rules_installed() {
  local rule
  for rule in "$ROOT_DIR"/system/udev/*.rules; do
    cmp -s "$rule" "/etc/udev/rules.d/${rule##*/}" || return 1
  done
}
clamav_daemon_disabled() { service_disabled clamav-daemon.socket && service_disabled clamav-daemon.service; }
# Rules in /etc/udev/rules.d/ that neither this repository, a package nor snapd installed, which a fresh install
# would not have
no_unmanaged_udev_rules() {
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
check "Docker Desktop does not start at login" user_service_disabled docker-desktop
check "Docker Desktop starts in the tray, without the Dashboard, and not at login" docker_desktop_settings
check "Docker Engine does not start at boot" service_disabled docker.service
check "containerd does not start at boot" service_disabled containerd.service

echo "== Kubernetes"
check "MicroK8s does not start at boot" microk8s_not_started_at_boot
# shellcheck disable=SC2088 # the ~ is part of the message
check "~/.kube/config is readable only by you" kubeconfig_private

echo "== Security"
check "ClamAV virus definitions are kept up to date (clamav-freshclam)" service_running clamav-freshclam
check "the ClamAV daemon does not run in the background" clamav_daemon_disabled
check "GitHub CLI is logged in" gh auth status

echo "== Hardware"
check "the udev rules in system/udev/ are installed" udev_rules_installed
check "every udev rule in /etc/udev/rules.d/ comes from system/udev/, a package or snapd" no_unmanaged_udev_rules

echo "== Apps"
check "OpenLogi is installed" installed openlogi
check "Solaar is not installed" not_installed solaar
check "balenaEtcher is installed" installed balena-etcher
check "Wayland Scroll Factor is installed and enabled" wsf_enabled
check "IDplug Classic is installed" installed idplugclassic
check "Chrome can use the electronic ID card (IDEMIA IDPlug module)" chrome_has_idplug
check "Firefox can use the electronic ID card (module, policy and pcscd connection)" firefox_has_idplug

echo "== GNOME"
check "every extension in gnome/extensions.txt is enabled" extensions_enabled

if [ "$failed_checks" -gt 0 ]; then
  echo "$failed_checks check(s) failed" >&2
  exit 1
fi
echo "Everything checks out"
