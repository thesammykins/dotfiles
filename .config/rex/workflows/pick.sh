#!/bin/zsh
# Saved-command picker, run in a floating pane by the `workflows` action in
# init.lua. $1 is the terminal the picker was opened from: the chosen command
# is typed at that terminal's prompt without Enter.
#
# fzf calls this script again for its key bindings:
#   pick.sh --list            picker rows: "LINE<TAB>description<TAB>command"
#   pick.sh --add [COMMAND [DESC]]  append, asking for whatever is not given
#   pick.sh --delete LINE     remove that line of the file
#
# The list is this Mac's own file. It starts as a copy of the commands.txt
# beside this script in the dotfiles repo, so what you save is never tracked.
file="${REX_WORKFLOWS:-$HOME/.config/rex/workflows/commands.txt}"
# Blocks start with the server's environment, which lacks Homebrew's PATH.
path=(/opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" $path)
[[ -e $file ]] || { mkdir -p "${file:h}" && cp "${0:A:h}/commands.txt" "$file" } || exit 1

rows() {
  # The file line number rides along hidden so --delete can find the entry.
  awk -F '  ## ' '!/^[[:space:]]*(#|$)/ {
    printf "%d\t%-38s\t%s\n", NR, ($2 == "" ? "-" : $2), $1 }' "$file"
}

add() {
  # With both arguments (even an empty description) nothing is asked.
  local cmd="$1" desc="$2"
  if [[ -z $cmd ]]; then
    read -r "cmd?Command: " || return
  fi
  # One line per entry, and "  ## " is the separator, so neither may appear.
  cmd=${${cmd//$'\n'/ }//  \#\# / # }
  [[ -n ${cmd//[[:space:]]/} ]] || return
  if (( ARGC < 2 )); then
    read -r "desc?Description (optional): " || return
  fi
  desc=${desc//$'\n'/ }
  if [[ -n $desc ]]; then
    print -r -- "$cmd  ## $desc" >> "$file"
  else
    print -r -- "$cmd" >> "$file"
  fi
}

case "$1" in
  --list)   rows; exit 0 ;;
  --add)    shift; add "$@"; exit 0 ;;
  --delete) [[ $2 == <-> ]] && sed -i '' "${2}d" "$file"; exit 0 ;;
esac

origin="$1"
self="$REX_BLOCK"
finish() {
  rex block focus "$origin" >/dev/null 2>&1
  # A floating pane whose program exits stays open as "exited", so close it.
  rex block close "$self" >/dev/null 2>&1
}
trap finish EXIT

me=${(q)0}
# ctrl-e leaves fzf and runs the editor here, then shows the list again.
# Run inside fzf's execute(), fresh drew its UI but ignored typing.
while true; do
  out="$(rows | fzf --delimiter '\t' --with-nth 2.. --tabstop 2 --reverse --height 100% \
    --prompt 'saved command > ' \
    --header 'enter: insert   ctrl-a: add   ctrl-d: delete   ctrl-e: edit file   esc: close' \
    --expect ctrl-e \
    --bind "ctrl-a:execute($me --add)+reload($me --list)" \
    --bind "ctrl-d:execute-silent($me --delete {1})+reload($me --list)")"
  rc=$?
  # With --expect, the first line is the key that ended fzf (empty for enter).
  if [[ ${out%%$'\n'*} == ctrl-e ]]; then
    (cd "${file:h}" && ${EDITOR:-${${commands[fresh]:+fresh}:-vim}} "$file")
    continue
  fi
  (( rc == 0 )) || exit 0
  break
done
line=${out#*$'\n'}
cmd="${line#*$'\t'*$'\t'}"

# Ask once for each distinct {{placeholder}}.
typeset -a names
rest=$cmd
while [[ $rest =~ '\{\{([A-Za-z0-9_-]+)\}\}' ]]; do
  names+=($match[1])
  rest=${rest#*$MATCH}
done
for name in ${(u)names}; do
  read -r "value?$name: " || exit 0
  cmd=${cmd//"{{$name}}"/$value}
done

# Only type into a shell at its prompt; an editor or REPL would eat the text.
case "$(rex block call -b "$origin" process | jq -r '.foreground.name')" in
  zsh|-zsh|bash|fish|sh) ;;
  *) print -u2 "That pane isn't at a shell prompt, so nothing was typed."; sleep 2; exit 0 ;;
esac
rex block call -b "$origin" write "$(jq -n --arg d "$cmd" '{data: $d}')" >/dev/null
