#!/bin/bash
# Undo what earlier versions of the installer set up and the current one no longer does, so a machine set up by one of
# them ends up like a fresh install. packages.sh runs this before it adds the sources. Each migration does nothing on a
# machine that never had what it removes, so it is safe to run again. Delete a migration once every machine you use
# has run it (with `make packages`, or `bash scripts/migrations.sh` on its own).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# 2026-10-26: OpenLogi replaced Solaar, so Solaar's PPA is no longer added
if compgen -G "/etc/apt/sources.list.d/solaar-unifying-*" > /dev/null; then
  sudo add-apt-repository -y --remove ppa:solaar-unifying/stable
fi

# 2026-10-27: .NET comes from Ubuntu's archive, so Microsoft's repository is no longer added. Purging
# packages-microsoft-prod removes its sources entry and key.
if dpkg -s packages-microsoft-prod > /dev/null 2>&1; then
  apt_get purge -y packages-microsoft-prod
fi

# 2026-11-07: the repositories in packages/repositories.txt are written as <name>.sources files in the deb822 format,
# instead of the one-line <name>.list files that earlier versions wrote
while read -r name _; do
  if [ -e "/etc/apt/sources.list.d/$name.list" ]; then
    sudo rm -f "/etc/apt/sources.list.d/$name.list"
  fi
done < <(read_list repositories.txt)

echo "Nothing left over from earlier versions"
