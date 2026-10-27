# shellcheck shell=bash
# Helpers shared by packages.sh, update.sh and drift.sh. Source it; it sets ROOT_DIR.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Installed before anything else: what packages.sh needs to add the other sources
# shellcheck disable=SC2034 # used by the scripts that source this file
PREREQUISITES=(curl flatpak jq software-properties-common stow wget)

# Print the entries of a list in packages/, without comments and blank lines
read_list() {
  grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/packages/$1" | sed -E 's/[[:space:]]+#.*$//'
}

failed_steps=()
# step <name> <function>: run a step in a subshell with `set -e` in force (it would be ignored if the step
# ran as an `if` or `||` condition), and remember it if it fails instead of stopping
step() {
  local name="$1" status
  shift
  echo "== $name"
  set +e
  (set -e; "$@")
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    echo "!! $name failed (exit code $status)" >&2
    failed_steps+=("$name")
  fi
}

# finish <message>: print the message, or list the failed steps and exit with an error
finish() {
  if [ "${#failed_steps[@]}" -gt 0 ]; then
    echo "Done, but these steps failed: ${failed_steps[*]}. Scroll up for their errors." >&2
    exit 1
  fi
  echo "$1"
}
