#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# install.sh links each listed path without checking it; a typo or a deleted
# file would leave a dangling link in $HOME.
@test "every managed path exists in the repo" {
  while IFS= read -r relative; do
    [ -z "$relative" ] || [ -f "$DOTFILES_DIR/$relative" ] || { echo "missing: $relative"; false; }
  done < "$DOTFILES_DIR/scripts/managed-paths.txt"
}
