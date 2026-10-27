#!/bin/bash
# Install Docker Desktop, or upgrade it when Docker publishes a newer build. It is installed from a
# downloaded .deb, not a repository, so APT never upgrades it. Each download is checked against the
# checksums.txt Docker publishes next to it.
# Usage: docker-desktop.sh [--check]
#   --check  only confirm that the latest build and its checksum can be found, without installing anything

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

BASE_URL="https://desktop.docker.com/linux/main/amd64"

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  "") ;;
  *) echo "Usage: $(basename "$0") [--check]" >&2; exit 1 ;;
esac

# The update feed links each release as .../amd64/<build>/docker-desktop-amd64.deb
latest_build="$(curl -fsSL "$BASE_URL/appcast.xml" \
  | grep -oE 'amd64/[0-9]+/docker-desktop-amd64\.deb' | cut -d/ -f2 | sort -n | tail -1)"
if [ -z "$latest_build" ]; then
  echo "No build found in the Docker Desktop update feed" >&2
  exit 1
fi
checksum="$(curl -fsSL "$BASE_URL/$latest_build/checksums.txt" | awk '$2 == "*docker-desktop-amd64.deb" { print $1 }')"
if [ -z "$checksum" ]; then
  echo "No checksum for docker-desktop-amd64.deb in build $latest_build" >&2
  exit 1
fi

if [ "$check_only" = true ]; then
  echo "Docker Desktop build $latest_build (sha256:$checksum)"
  exit 0
fi

# The installed version ends in the build number, e.g. 4.89.0-238018
installed_build=""
if dpkg-query -W docker-desktop > /dev/null 2>&1; then
  installed_build="$(dpkg-query -W -f='${Version}' docker-desktop)"
  installed_build="${installed_build##*-}"
fi
if [ -n "$installed_build" ] && [ "$latest_build" -le "$installed_build" ]; then
  echo "Docker Desktop is up to date (build $installed_build)"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
# apt runs as _apt and must be able to read the download
chmod 755 "$tmp_dir"
deb="$tmp_dir/docker-desktop-amd64.deb"
curl -fL "$BASE_URL/$latest_build/docker-desktop-amd64.deb" -o "$deb"
echo "$checksum  $deb" | sha256sum --check --quiet
chmod 644 "$deb"
sudo apt-get install -y "$deb"
