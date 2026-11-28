#!/bin/bash
# The store Docker Desktop keeps registry credentials in: pass, with a GPG key named "Docker Desktop". GnuPG asks for
# the key's passphrase in a dialog; when Docker Desktop first needs it, the dialog can save it in the login keyring,
# which unlocks it from then on when you log in.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="Docker credentials"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

KEY_NAME="Docker Desktop"

# Print the ID of the key, if there is one
key_id() {
  gpg --list-keys --with-colons "$KEY_NAME" 2> /dev/null | awk -F: '/^pub/ { print $5; exit }' || true
}

on_install() {
  if [ -d "$HOME/.password-store" ]; then
    echo "pass is already set up"
    return
  fi
  local id
  id="$(key_id)"
  if [ -z "$id" ]; then
    # Never expires: with an expired key, pass cannot store credentials and `docker login` fails. GnuPG's default
    # is 3 years.
    gpg --batch --quick-gen-key "$KEY_NAME" default default never
    id="$(key_id)"
  fi
  pass init "$id"
}

# The agent marks each secret key P when a passphrase protects it, and C when it does not
key_has_passphrase() {
  local keygrips keygrip
  keygrips="$(gpg --list-secret-keys --with-colons --with-keygrip "$KEY_NAME" 2> /dev/null \
    | awk -F: '$1 == "grp" { print $10 }')"
  [ -n "$keygrips" ] || { echo "there is no secret key named $KEY_NAME" >&2; return 1; }
  for keygrip in $keygrips; do
    gpg-connect-agent "keyinfo $keygrip" /bye \
      | awk '$2 == "KEYINFO" { found = 1; protected = ($8 == "P") } END { exit !(found && protected) }' \
      || { echo "add a passphrase with: gpg --passwd '$KEY_NAME'" >&2; return 1; }
  done
}

# Machines set up before keys were made to never expire have one that expires after 3 years
key_never_expires() {
  local keys fingerprint expiry
  keys="$(gpg --list-keys --with-colons "$KEY_NAME" 2> /dev/null)"
  [ -n "$keys" ] || { echo "there is no key named $KEY_NAME" >&2; return 1; }
  fingerprint="$(awk -F: '$1 == "fpr" { print $10; exit }' <<< "$keys")"
  # The key and the subkey pass encrypts with
  expiry="$(awk -F: '($1 == "pub" || $1 == "sub") && $7 != "" { print $7 }' <<< "$keys" | sort -n | head -1)"
  if [ -n "$expiry" ]; then
    echo "it expires on $(date -d "@$expiry" +%F); remove the expiry with:" \
      "gpg --quick-set-expire $fingerprint never && gpg --quick-set-expire $fingerprint never '*'" >&2
    return 1
  fi
}

on_doctor() {
  check "the GPG key Docker Desktop stores credentials with has a passphrase" key_has_passphrase
  check "the GPG key Docker Desktop stores credentials with never expires" key_never_expires
}

component_main "$@"
