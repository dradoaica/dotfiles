# shellcheck shell=bash
# Homebrew. A parent shell, or the GNOME session through .profile, may have loaded it already and exported
# HOMEBREW_PREFIX; loading it again would put Homebrew on PATH once more for every nested shell.
for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
  if [ -x "$brew" ]; then
    case ":$PATH:" in
      *":${HOMEBREW_PREFIX:-/nonexistent}/bin:"*) ;;
      *) cached_eval brew-shellenv "$brew" "$brew" shellenv ;;
    esac
    break
  fi
done
unset brew
