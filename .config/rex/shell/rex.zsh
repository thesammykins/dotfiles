# Rex shell integration for zsh, sourced from ~/.zshrc when TERM_PROGRAM=rex.
# Source it after starship so the prompt-end mark lands after starship's prompt.
#
# 1. Prompt marks (OSC 133). Rex needs them for Jump to Previous/Next Prompt
#    (cmd+up / cmd+down), and a new prompt clears any `working` status the
#    command below left behind. Starship doesn't emit them.
# 2. Long-command status (OSC 7501, Rex's Program Status Protocol). Commands
#    that take REX_STATUS_AFTER seconds or more (default 10) report done or
#    error, so Rex shows tab dots, Dock badges and notifications for builds
#    and tests.
# 3. Current directory (OSC 7), which starship doesn't send either.
# 4. Ctrl-X Ctrl-E opens the command line in $EDITOR.

[[ -o interactive ]] || return 0

zmodload zsh/datetime
autoload -Uz add-zsh-hook edit-command-line

: ${REX_STATUS_AFTER:=10}
# Interactive programs and agents. Agents report their own status, and a
# `done` after closing vim or ssh would be noise.
(( ${+REX_STATUS_IGNORE} )) || typeset -ga REX_STATUS_IGNORE=(
  vi vim nvim nano emacs hx less more man bat
  ssh mosh et tmux zellij
  claude codex opencode amp ax ask
  top htop btop yazi lazygit tig fzf watch tail
  rex z zi cd
)

typeset -g _rex_cmd_ran= _rex_status_start= _rex_status_cmd= _rex_status_app=

_rex_osc7501() {
  # $1 state, $2 app, $3 optional message (base64 so it can't break the sequence).
  # Reports go to their own record (id=cmd) so clearing it never wipes the
  # status an agent left on the root record of the same terminal.
  # Braces matter: "$1:a..." would apply zsh's :a (absolute path) modifier.
  local body="state=${1}:id=cmd:app=${2}"
  if [[ -n $3 ]]; then
    local msg=${3//[[:cntrl:]]/ }
    body+=":msg=$(print -rn -- "${msg[1,200]}" | base64 | tr -d '\n')"
  fi
  print -rn -- $'\e]7501;'"$body"$'\e\\'
}

_rex_duration() {
  local s=$1
  if (( s >= 3600 )); then print -rn -- "$(( s / 3600 ))h $(( s % 3600 / 60 ))m"
  elif (( s >= 60 )); then print -rn -- "$(( s / 60 ))m $(( s % 60 ))s"
  else print -rn -- "${s}s"; fi
}

_rex_preexec() {
  print -rn -- $'\e]133;C\a'
  _rex_cmd_ran=1

  # The program name: skip wrappers, VAR=value and separators like `X=1; cmd`,
  # and expand one level of alias.
  local -a words=(${(z)1})
  while (( $#words )) && [[ $words[1] == (sudo|time|nohup|noglob|command|builtin|exec|caffeinate|*=*|\;|\&\&|\|\|) ]]; do
    shift words
  done
  local prog=${words[1]:t}
  [[ -n ${aliases[$prog]} ]] && prog=${${(z)aliases[$prog]}[1]}
  [[ $prog == noglob ]] && prog=${${(z)aliases[${words[1]}]}[2]}
  [[ -z $prog || ${REX_STATUS_IGNORE[(Ie)$prog]} -gt 0 ]] && return

  _rex_status_start=$EPOCHSECONDS
  _rex_status_cmd=${1%%$'\n'*}
  # app must match [A-Za-z0-9_.+-]{1,32}; anything else is dropped by Rex.
  _rex_status_app=${${prog//[^A-Za-z0-9_.+-]/}[1,32]}
  [[ -n $_rex_status_app ]] || _rex_status_app=shell
  _rex_osc7501 working $_rex_status_app
}

_rex_precmd() {
  local ret=$?
  if [[ -n $_rex_cmd_ran ]]; then
    print -rn -- $'\e]133;D;'"$ret"$'\a'
    _rex_cmd_ran=
  fi

  if [[ -n $_rex_status_start ]]; then
    local elapsed=$(( EPOCHSECONDS - _rex_status_start ))
    local took=$(_rex_duration $elapsed)
    if (( elapsed < REX_STATUS_AFTER || ret == 130 )); then
      # Short or Ctrl-C'd: nothing to report. Rex turns a leftover `working`
      # into `done` when the prompt returns, so clear the record instead.
      print -rn -- $'\e]7501;state=clear:id=cmd\e\\'
    elif (( ret == 0 )); then
      _rex_osc7501 done $_rex_status_app "$_rex_status_cmd · $took"
    else
      _rex_osc7501 error $_rex_status_app "$_rex_status_cmd · exit $ret · $took"
    fi
    _rex_status_start= _rex_status_cmd= _rex_status_app=
  fi

  # Current directory (OSC 7), for Rex's pwd, pwd_changed events and panes
  # that open where you are. Escape % first, then spaces.
  local dir=${${PWD//\%/%25}// /%20}
  print -rn -- $'\e]7;file://'"${HOST}${dir}"$'\a'

  print -rn -- $'\e]133;A\a'
}

add-zsh-hook preexec _rex_preexec
# First in line, so $? is still the command's exit status.
precmd_functions=(_rex_precmd ${precmd_functions:#_rex_precmd})

# Prompt end mark. %{...%} keeps zsh from counting it as visible width.
[[ $PROMPT == *$'\e]133;B'* ]] || PROMPT+="%{"$'\e]133;B\a'"%}"

zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Ctrl-X Ctrl-A saves the current command line to the saved-commands list
# (ctrl+shift+r), asking for a description. The line stays as it was.
# (Not Ctrl-S: the terminal treats it as flow control and zsh never sees it.)
autoload -Uz read-from-minibuffer
_rex_save_command() {
  [[ -n ${BUFFER//[[:space:]]/} ]] || { zle -M 'Nothing to save'; return }
  # Asks below the prompt, like Ctrl-R search, so the line isn't redrawn.
  read-from-minibuffer 'Description (Enter to skip, Ctrl-G to cancel): ' || return
  "$HOME/.config/rex/workflows/pick.sh" --add "$BUFFER" "$REPLY" &&
    zle -M 'Saved. Ctrl-Shift-R to use it.'
}
zle -N _rex_save_command
bindkey '^X^A' _rex_save_command
