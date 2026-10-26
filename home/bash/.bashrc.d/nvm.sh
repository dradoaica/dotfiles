# shellcheck shell=bash
# nvm, loaded on first use: loading it takes most of a new shell's startup time
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # Put the newest installed Node matching the default alias (e.g. 24) on PATH now,
  # so node, npm and global npm tools work without loading nvm
  nvm_default="$(cat "$NVM_DIR/alias/default" 2>/dev/null)"
  nvm_default_dir="$(find "$NVM_DIR/versions/node" -mindepth 1 -maxdepth 1 -type d \
    \( -name "v${nvm_default#v}" -o -name "v${nvm_default#v}.*" \) 2>/dev/null | sort -V | tail -1)"
  if [ -n "$nvm_default" ] && [ -n "$nvm_default_dir" ]; then
    PATH="$nvm_default_dir/bin:$PATH"
    nvm() {
      unset -f nvm
      . "$NVM_DIR/nvm.sh"
      nvm "$@"
    }
  else
    # The default is an alias such as lts/* that only nvm can resolve
    . "$NVM_DIR/nvm.sh"
  fi
  unset nvm_default nvm_default_dir
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
fi
