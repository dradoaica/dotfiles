# shellcheck shell=bash
# Helpers shared by the tests in tests/. Source it; `make test` runs every other file here.

# fail <message>: report a failed expectation and stop the test
fail() {
  echo "FAIL  $1" >&2
  exit 1
}

# ok <message>: report a met expectation
ok() { echo "ok    $1"; }
