#!/bin/bash
# Test the components in scripts/components/ against what lib.sh expects of them, and run_components itself on made-up
# components in a copy of lib.sh. Nothing on the machine it runs on is read or changed. CI runs it, and so does
# `make test`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT_DIR/tests/lib.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

echo "== The components"
# shellcheck source=scripts/lib.sh
source "$ROOT_DIR/scripts/lib.sh"
listed="$(printf '%s\n' "${COMPONENTS[@]}" | sort)"
present="$(find "$ROOT_DIR/scripts/components" -maxdepth 1 -name '*.sh' -printf '%f\n' | sed 's/\.sh$//' | sort)"
[ "$listed" = "$present" ] || fail "COMPONENTS in lib.sh and the scripts in scripts/components/ differ:
$(diff <(echo "$listed") <(echo "$present") | grep '^[<>]')"
ok "every script in scripts/components/ is listed in COMPONENTS, and every name there has a script"
for name in "${COMPONENTS[@]}"; do
  description="$(bash "$ROOT_DIR/scripts/components/$name.sh" describe)" || fail "$name cannot describe itself"
  [ "$(wc -l <<< "$description")" -ge 2 ] || fail "$name defines none of the actions"
  # Functions named like an action that is not one, such as on_docter, would never run
  unknown="$(grep -oE '^(function +)?on_[a-z_]+ *\(\)' "$ROOT_DIR/scripts/components/$name.sh" \
    | sed -E 's/^(function +)?on_//; s/ *\(\)$//' \
    | grep -vxE "$(IFS='|'; echo "${COMPONENT_ACTIONS[*]}")" || true)"
  [ -z "$unknown" ] || fail "$name defines functions for actions that do not exist: $unknown"
done
ok "every component has a title and at least one action, and no function for an action that does not exist"

echo "== run_components"
mkdir -p "$TEST_DIR/scripts/components"
cp "$ROOT_DIR/scripts/lib.sh" "$TEST_DIR/scripts/"
# make_component <name> <title> <body>
make_component() {
  {
    echo '#!/bin/bash'
    echo "TITLE=\"$2\""
    echo 'set -euo pipefail'
    # The $(...) and ${...} are for the component, written as they are
    # shellcheck disable=SC2016
    echo 'source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"'
    echo "$3"
    # shellcheck disable=SC2016
    echo 'component_main "$@"'
  } > "$TEST_DIR/scripts/components/$1.sh"
}
make_component first "First" '
on_install() { echo "installing first"; }
on_doctor() { check "passes" true; check "fails" false; }'
make_component second "Second" '
on_install() { false; echo "not reached"; }
# A command that fails outside a check must not stop the checks after it
on_doctor() { false; check "runs after a failing command" true; }'

# In a subshell each, with lib.sh from the copy, so failed_steps and failed_checks start empty
output="$(
  source "$TEST_DIR/scripts/lib.sh"
  COMPONENTS=(first second)
  run_components install 2>&1
  echo "failed steps: ${failed_steps[*]}"
)"
[ "$(grep '^== ' <<< "$output" | paste -sd' ')" = "== First == Second" ] || fail "the steps ran as: $output"
grep -qx "failed steps: Second" <<< "$output" || fail "the failed step was not recorded: $output"
! grep -q "not reached" <<< "$output" || fail "an install went on after a command failed"
ok "install runs each component as a step, in order, and records the one that failed"

output="$(
  source "$TEST_DIR/scripts/lib.sh"
  COMPONENTS=(first second)
  run_components doctor 2>&1
  echo "failed checks: $failed_checks"
)"
grep -qx "failed checks: 1" <<< "$output" || fail "doctor counted the failed checks wrong: $output"
grep -q "^ok    runs after a failing command" <<< "$output" || fail "a failing command stopped the checks: $output"
ok "doctor counts each component's failed checks, and runs them past a failing command"

output="$(
  source "$TEST_DIR/scripts/lib.sh"
  COMPONENTS=(first)
  run_components update 2>&1
)"
[ -z "$output" ] || fail "a component without an update action was run: $output"
ok "a component is skipped for the actions it does not define"

output="$(
  source "$TEST_DIR/scripts/lib.sh"
  COMPONENTS=(first missing)
  run_components doctor 2>&1
  echo "failed checks: $failed_checks"
)"
grep -q "Component missing failed to describe itself" <<< "$output" || fail "a missing component was not reported"
grep -qx "failed checks: 2" <<< "$output" || fail "a missing component was not counted as a failure: $output"
ok "a component listed in COMPONENTS but missing is reported, and counts as a failure"
