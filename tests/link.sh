#!/bin/bash
# Test link.sh, and the shells the linked files set up, in an empty home directory: linking backs up the files it
# replaces and changes nothing the second time, a link to a file no longer in the repository is reported and removed,
# interactive and login shells start, new terminals keep a history longer than Ubuntu's 2,000 lines, and unlinking
# removes the links. Each shell starts with an empty environment, as a fresh login would, so nothing of the machine it
# runs on is read or changed. Needs stow; CI runs it, and so does `make test`.

# The $... in single quotes are for the shells this test starts
# shellcheck disable=SC2016

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT_DIR/tests/lib.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export HOME="$TEST_DIR/home"
mkdir -p "$HOME"
LINK_SH="$ROOT_DIR/scripts/link.sh"

# fresh <command...>: run a command with nothing in its environment but the home directory, as at a fresh login.
# Interactive shells complain on stderr that they have no terminal.
fresh() { env -i HOME="$HOME" PATH=/usr/local/bin:/usr/bin:/bin TERM=xterm-256color "$@" 2> /dev/null; }

echo "== Link"
cp /etc/skel/.bashrc /etc/skel/.profile "$HOME/"
bash "$LINK_SH" > /dev/null
bash "$LINK_SH" --check > /dev/null || fail "a file is not linked after linking"
ok "every file is linked"
compgen -G "$HOME/.dotfiles-backup/*/.bashrc" > /dev/null || fail "the .bashrc that was there was not backed up"
ok "the files that were there are backed up"
# Read into a variable before grep: under pipefail, `grep -q` stopping at the first match can fail the pipeline while
# link.sh is still writing
output="$(bash "$LINK_SH")"
! grep -q "Backed up" <<< "$output" || fail "a second run backed up files again"
ok "a second run changes nothing"

ln -s "$ROOT_DIR/home/bash/.removed" "$HOME/.removed"
! bash "$LINK_SH" --check > /dev/null 2>&1 || fail "a link to a file no longer in the repository was not reported"
output="$(bash "$LINK_SH")"
grep -q "Removed ~/.removed" <<< "$output" || fail "a link to a file no longer in the repository was not removed"
[ ! -L "$HOME/.removed" ] || fail "the link to a removed file is still there"
bash "$LINK_SH" --check > /dev/null || fail "something is reported after the link to a removed file is gone"
ok "a link to a file no longer in the repository is reported, then removed"

echo "== Shells"
[ "$(fresh bash -ic 'echo "NVM_DIR=$NVM_DIR"')" = "NVM_DIR=$HOME/.nvm" ] \
  || fail "an interactive shell did not load .bashrc.d/"
ok "an interactive shell loads the linked .bashrc and .bashrc.d/"
for shell in bash sh; do
  [ "$(fresh "$shell" -lc 'echo "NVM_DIR=$NVM_DIR"')" = "NVM_DIR=$HOME/.nvm" ] \
    || fail "a $shell login shell did not load .profile"
done
ok "login shells, as the GNOME session starts, load the linked .profile from bash and sh"

# Fill the history file with more than the 2,000 lines Ubuntu's .bashrc trims ~/.bash_history to, then check that
# new terminals still load all of it, the second one too
histfile="$(fresh bash -i <<< 'echo "$HISTFILE"' | tail -1)"
[ "$histfile" != "$HOME/.bash_history" ] || fail "the history is still kept in ~/.bash_history"
seq 1 5000 | sed 's/^/echo /' > "$histfile"
for shell in first second; do
  entries="$(fresh bash -i <<< 'history | wc -l' | tail -1)"
  [ "$entries" -ge 5000 ] || fail "the $shell new terminal loaded $entries history entries, not 5000"
done
ok "new terminals keep a history longer than Ubuntu's 2,000 lines"

echo "== Unlink"
bash "$LINK_SH" --unlink > /dev/null
! bash "$LINK_SH" --check > /dev/null 2>&1 || fail "the files are still linked after unlinking"
[ ! -e "$HOME/.config/git/config" ] || fail "the Git config is still linked after unlinking"
ok "unlinking removes the links"
