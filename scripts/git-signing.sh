#!/bin/bash
# Sign Git commits and tags with an SSH key, so GitHub shows them as Verified. Creates ~/.ssh/id_ed25519 if it is
# missing (ssh-keygen asks for a passphrase), adds it to GitHub as a signing key, and writes the Git settings to
# ~/.config/git/config.local, which is not tracked: the key belongs to this machine. Safe to re-run.
# Usage: git-signing.sh

set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"
LOCAL_CONFIG="$HOME/.config/git/config.local"
# Lets `git log --show-signature` and `git verify-commit` check signatures locally
ALLOWED_SIGNERS="$HOME/.config/git/allowed_signers"

gh auth status > /dev/null 2>&1 || { echo "Sign in to the GitHub CLI first: gh auth login" >&2; exit 1; }

if [ ! -f "$KEY" ]; then
  [ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$(git config --global --includes user.email)" -f "$KEY"
fi
public_key="$(cut -d' ' -f1,2 "$KEY.pub")"

# Command output is read into variables before grep: under pipefail, `grep -q` stopping at the first match can fail
# the pipeline.

# Git signs through the SSH agent (GNOME's, which asks for the passphrase in a dialog), so commits made from IDEs,
# which have no terminal to ask in, are signed too. ssh-add -L fails when the agent holds no keys yet.
agent_keys="$(ssh-add -L 2> /dev/null || true)"
if ! grep -qF "$public_key" <<< "$agent_keys"; then
  ssh-add "$KEY"
fi

# Adding a signing key needs a permission that `gh auth login` does not ask for; gh asks for it in the browser once
auth_status="$(gh auth status 2>&1)"
if ! grep -q "admin:ssh_signing_key" <<< "$auth_status"; then
  gh auth refresh --hostname github.com --scopes admin:ssh_signing_key
fi
github_keys="$(gh api user/ssh_signing_keys --jq '.[].key')"
if grep -qxF "$public_key" <<< "$github_keys"; then
  echo "GitHub already has this signing key"
else
  gh ssh-key add "$KEY.pub" --type signing --title "$(hostname) signing"
fi

touch "$ALLOWED_SIGNERS"
if ! grep -qF "$public_key" "$ALLOWED_SIGNERS"; then
  echo "$(git config --global --includes user.email) namespaces=\"git\" $public_key" >> "$ALLOWED_SIGNERS"
fi

git config --file "$LOCAL_CONFIG" gpg.format ssh
git config --file "$LOCAL_CONFIG" user.signingkey "$KEY.pub"
git config --file "$LOCAL_CONFIG" gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"
git config --file "$LOCAL_CONFIG" commit.gpgsign true
git config --file "$LOCAL_CONFIG" tag.gpgsign true
echo "Git now signs commits and tags with $KEY"
