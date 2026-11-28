#!/bin/bash
# MicroK8s (a snap, from packages/snap.txt), merged into ~/.kube/config next to any other clusters, and stopped so it
# does not run in the background or start at boot. Run `microk8s start` when you need it, and `microk8s stop` after.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Kubernetes (MicroK8s)"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  sudo usermod -a -G microk8s "$USER"
  mkdir -p ~/.kube
  sudo chown -R "$USER" ~/.kube
  # Group membership applies after the next login, so use sudo here instead of newgrp
  sudo microk8s start
  sudo microk8s status --wait-ready
  # Merge the MicroK8s cluster into ~/.kube/config, keeping any other clusters and the current context
  local microk8s_config current_context
  microk8s_config="$(mktemp ~/.kube/microk8s.XXXXXX)"
  # The redirect runs as the user on purpose, so the file is owned by the user
  # shellcheck disable=SC2024
  sudo microk8s config > "$microk8s_config"
  if [ -s ~/.kube/config ]; then
    current_context="$(kubectl config current-context 2> /dev/null || true)"
    # For entries in both files the first file wins, so fresh MicroK8s credentials replace stale ones
    KUBECONFIG="$microk8s_config:$HOME/.kube/config" kubectl config view --flatten > "$microk8s_config.merged"
    mv "$microk8s_config.merged" ~/.kube/config
    if [ -n "$current_context" ]; then
      kubectl config use-context "$current_context" > /dev/null
    fi
  else
    cp "$microk8s_config" ~/.kube/config
  fi
  rm -f "$microk8s_config"
  # It holds cluster credentials
  chmod 600 ~/.kube/config
  # `microk8s stop` also stops it starting at boot
  sudo microk8s stop
}

not_started_at_boot() {
  local services
  services="$(snap services microk8s)" || return 1
  ! awk 'NR > 1 { print $2 }' <<< "$services" | grep -qx enabled
}
kubeconfig_private() { [ ! -e "$HOME/.kube/config" ] || [ "$(stat -c '%a' "$HOME/.kube/config")" = 600 ]; }

on_doctor() {
  check "MicroK8s does not start at boot" not_started_at_boot
  # shellcheck disable=SC2088 # the ~ is part of the message
  check "~/.kube/config is readable only by you" kubeconfig_private
}

component_main "$@"
