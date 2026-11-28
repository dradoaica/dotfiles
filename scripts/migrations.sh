#!/bin/bash
# Undo what earlier versions of the installer set up and the current one no longer does, so a machine set up by one of
# them ends up like a fresh install. packages.sh runs this before it adds the sources. Each migration does nothing on a
# machine that never had what it removes, so it is safe to run again. Delete a migration once every machine you use
# has run it (with `make packages`, or `bash scripts/migrations.sh` on its own).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# None at the moment. Add each as a dated block that does nothing on a machine without what it removes, e.g.:
#
#   # <date>: <what replaced it>, so <what> is no longer installed
#   if deb_installed <package>; then
#     apt_get purge -y <package>
#   fi

echo "Nothing left over from earlier versions"
