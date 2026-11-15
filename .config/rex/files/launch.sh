#!/bin/sh
# Open a file manager beside terminal block $1, rooted at that terminal's cwd.
# $2 picks it. fresh (the default) is an editor with a file tree. yazi is a
# picker that hands its result back to that terminal on quit: a picked file's
# path is typed at its prompt, otherwise a changed directory becomes a `cd`.
origin="$1"
manager="${2:-fresh}"
# Rex starts this without the interactive shell's PATH or EDITOR.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
if [ -z "${EDITOR:-}" ]; then
  if command -v fresh >/dev/null 2>&1; then EDITOR=fresh; else EDITOR=vim; fi
fi
export PATH EDITOR VISUAL="${VISUAL:-$EDITOR}"

proc="$(rex block call -b "$origin" process)"
cwd="$(printf '%s' "$proc" | jq -r '.foreground.cwd // .home')"

# A Mac without fresh still gets a file manager on either key.
if [ "$manager" = fresh ] && command -v fresh >/dev/null 2>&1; then
  exec fresh "$cwd"
fi

chooser="$(mktemp)"
cwdfile="$(mktemp)"
trap 'rm -f "$chooser" "$cwdfile"' EXIT

# The opener in yazi.toml writes the picked path to REX_PICK_FILE.
YAZI_CONFIG_HOME="$HOME/.config/rex/files" REX_PICK_FILE="$chooser" yazi --cwd-file "$cwdfile" "$cwd"

# Only type into an idle shell; anything else (an editor, a REPL) would eat the keystrokes.
case "$(rex block call -b "$origin" process | jq -r '.foreground.name')" in
  zsh|-zsh|bash|fish|sh) ;;
  *) exit 0 ;;
esac

quote() { sed "s/'/'\\\\''/g"; }

if [ -s "$chooser" ]; then
  # No trailing Enter, so the user decides what to run with the path.
  quoted="$(head -n1 "$chooser" | quote)"
  rex block call -b "$origin" write "$(jq -n --arg d "'$quoted' " '{data: $d}')" >/dev/null
elif [ -s "$cwdfile" ] && [ "$(cat "$cwdfile")" != "$cwd" ]; then
  quoted="$(quote < "$cwdfile")"
  rex block call -b "$origin" write "$(jq -n --arg d "cd -- '$quoted'
" '{data: $d}')" >/dev/null
fi
