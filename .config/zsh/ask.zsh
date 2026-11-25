# Natural language in the shell, through whichever coding agent is installed.
# Sourced from ~/.zshrc.
#   ask QUESTION   one-shot answer; the agent can read files but not change them
#   ax TASK        hand a task to an interactive agent in a Rex split, here
#   # DESCRIPTION  press Enter to swap the line for a suggested command; it is
#                  never run until you press Enter again
#   plain English  a line of three or more words whose first word isn't a
#                  command, alias, function or path goes to an agent: a
#                  question (ends in ? or starts with how, what...) to ask,
#                  anything else to ax when in Rex. ASK_AUTO=0 turns this off.
# Settings (export in ~/.zshrc.local):
#   ASK_AGENT    claude | codex | opencode | custom (default: first one found)
#   ASK_MODEL    the agent's model name; unset uses its default (haiku for claude)
#   ASK_COMMAND  with ASK_AGENT=custom: a command that takes the instructions and
#                question as its last argument and prints the answer on stdout
# opencode has no read-only switch for scripted runs, so ask uses its plan agent.

_ask_agent() {
    if [[ -n "${ASK_AGENT:-}" ]]; then
        print -r -- "$ASK_AGENT"
        return
    fi
    local agent
    for agent in claude codex opencode; do
        (( $+commands[$agent] )) && { print -r -- "$agent"; return }
    done
    return 1
}

# Commands ask may run to answer: they look, never change anything. claude
# refuses any other command in a scripted run, as there is no one to ask.
_ASK_READ_ONLY=(du df ls stat file wc ps uptime sw_vers uname whoami vm_stat
    mdfind which 'diskutil list' 'git status' 'git log' 'git diff' 'brew list'
    'brew info')

# _ask_run MODE PROMPT: MODE is "answer" (reads files, runs _ASK_READ_ONLY) or
# "command" (no tools; the reply is a single command).
_ask_run() {
    local mode="$1" prompt="$2" agent sys tools=Read,Grep,Glob,Bash cmd
    local -a allowed=()
    for cmd in "${_ASK_READ_ONLY[@]}"; do allowed+=("Bash($cmd:*)"); done
    agent="$(_ask_agent)" || {
        print -u2 'ask: no agent found; install claude, codex or opencode, or set ASK_AGENT'
        return 1
    }
    if [[ "$mode" == command ]]; then
        tools=
        sys="Reply with exactly one zsh command for macOS and nothing else: no explanation, no code fences. Working directory: $PWD"
    else
        sys='You are answering inside a macOS zsh terminal. Be brief and plain, with no headings.'
    fi
    case "$agent" in
        claude)
            command claude -p --model "${ASK_MODEL:-haiku}" --tools "$tools" \
                --allowedTools "${allowed[@]}" \
                --no-session-persistence --disable-slash-commands \
                --append-system-prompt "$sys" -- "$prompt" </dev/null ;;
        codex)
            # codex narrates its run on stdout and stderr; keep only the final message.
            local reply
            reply="$(mktemp)"
            command codex exec --sandbox read-only --ephemeral --skip-git-repo-check --color never \
                -C "$PWD" ${ASK_MODEL:+-m "$ASK_MODEL"} --output-last-message "$reply" \
                -- "$sys"$'\n\n'"$prompt" >/dev/null 2>&1
            if [[ -s "$reply" ]]; then print -r -- "$(<"$reply")"; else print -u2 'ask: codex returned nothing'; fi
            rm -f "$reply" ;;
        opencode)
            command opencode run --agent plan ${ASK_MODEL:+-m "$ASK_MODEL"} "$sys"$'\n\n'"$prompt" ;;
        custom)
            local -a custom=(${(z)ASK_COMMAND})
            (( $#custom )) || { print -u2 'ask: set ASK_COMMAND when ASK_AGENT=custom'; return 1 }
            "${custom[@]}" "$sys"$'\n\n'"$prompt" ;;
        *)
            print -u2 "ask: unknown ASK_AGENT '$agent' (claude, codex, opencode, custom)"
            return 1 ;;
    esac
}

# `function NAME` on purpose: once the noglob alias below exists, sourcing this
# file again would expand `ask()` to `noglob ask()` and fail to parse.
function ask {
    [[ $# -gt 0 ]] || { print -u2 'usage: ask QUESTION'; return 2 }
    _ask_run answer "$*"
}
alias ask='noglob ask'

if [[ -n "${REX_BLOCK:-}" ]] && (( $+commands[rex] )); then
    function ax {
        [[ $# -gt 0 ]] || { print -u2 'usage: ax TASK'; return 2 }
        local agent
        agent="$(_ask_agent)" || { print -u2 'ax: no agent found'; return 1 }
        local -a argv
        local dir="$PWD"
        case "$agent" in
            claude)
                argv=("${commands[claude]}" "$*")
                # Claude never remembers trusting the home folder, so a task
                # typed there would wait on its trust prompt every time. Start
                # in a folder trusted once instead, with home added to it.
                if [[ "$PWD" == "$HOME" ]]; then
                    dir="${XDG_STATE_HOME:-$HOME/.local/state}/ax"
                    mkdir -p "$dir"
                    argv=("${commands[claude]}" --add-dir "$HOME" "In $HOME: $*")
                fi ;;
            codex) argv=("${commands[codex]}" "$*") ;;
            opencode) argv=("${commands[opencode]}" --prompt "$*") ;;
            *) print -u2 "ax: $agent has no interactive mode here"; return 1 ;;
        esac
        rex run -b "$REX_BLOCK" --split=below --ratio 45 --cwd "$dir" --shell=none -- "${argv[@]}"
    }
    alias ax='noglob ax'
fi

_ask_accept_line() {
    if [[ "$BUFFER" == '# '* ]]; then
        local cmd
        zle -R 'asking for a command...'
        cmd="$(_ask_run command "${BUFFER#\# }" 2>/dev/null)"
        # Drop code-fence lines an agent adds despite the instructions.
        cmd="${(F)${(f)cmd}:#\`\`\`*}"
        if [[ -n "$cmd" ]]; then
            BUFFER="$cmd"
            CURSOR=${#BUFFER}
        else
            zle -M 'no command suggested'
        fi
        zle redisplay
        return
    fi
    if _ask_is_prose "$BUFFER"; then
        local text="${BUFFER%"${BUFFER##*[![:space:]]}"}"
        if [[ "$text" == *'?' || "${${(L)text}%% *}" == (how|what|why|when|where|who|which|is|are|can|does|should|could|would) ]] ||
            (( ! $+functions[ax] )); then
            BUFFER="ask ${(qq)text}"
        else
            BUFFER="ax ${(qq)text}"
        fi
    fi
    zle .accept-line
}
zle -N accept-line _ask_accept_line

# True when LINE reads as English rather than a command: three or more words,
# no shell operators, and a first word that is a question word, or one the
# shell can't run, or a command followed by English rather than arguments.
_ask_is_prose() {
    [[ "${ASK_AUTO:-1}" != 0 ]] || return 1
    local -a words=(${=1})
    (( $#words >= 3 )) || return 1
    [[ "$1" != *[\|\;\&\<\>\$\`]* ]] || return 1
    local first="${words[1]}"
    [[ "$first" != *[/=~]* ]] || return 1
    # what, which and who are also commands, but rarely take three arguments.
    if [[ "${(L)first}" == (how|what|why|when|where|who|which) ]] &&
        [[ "$1" == *'?'* || $#words -ge 4 ]]; then
        return 0
    fi
    whence -- "$first" >/dev/null 2>&1 || return 0
    # A real command followed by plain words that address you ("tidy up my
    # downloads folder": tidy is HTML Tidy) is still English. No flags or
    # quoted arguments, and at least one word a command line rarely has.
    local w
    for w in "${words[@]:1}"; do
        [[ "$w" == [-\'\"]* ]] && return 1
    done
    for w in "${words[@]:1}"; do
        [[ "${(L)${w//[[:punct:]]/}}" == (my|me|our|your|the|please|this|these|those|everything|anything|something) ]] && return 0
    done
    return 1
}
