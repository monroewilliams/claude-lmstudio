#!/usr/bin/env bash
# LM Studio Model Selector
# Connects to an LM Studio instance, queries available models,
# and launches Claude Code with the selected model.

set -euo pipefail

trap 'printf "${ERROR} at or near line %s:\n\t%s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

function cleanup() {
    stty sane
    printf "\n"
}

ERROR="\e[0;31m[Error]\e[0m"

# Set this to the url of your LM Studio instance,
# or set LM_STUDIO_BASE_URL in your environment
export ANTHROPIC_BASE_URL="${LM_STUDIO_BASE_URL:-http://localhost:1234}"

# This isn't an actual auth token.
# Claude just needs something in ANTHROPIC_AUTH_TOKEN or it thinks you're not logged in.
# Extra points if you get this reference. ;)
export ANTHROPIC_AUTH_TOKEN="swordfish"

help() {
    cat <<EOF
claude-local

Connects to an LM Studio instance, queries available models,
and launches Claude Code with the selected model.

USAGE:
    ./claude-local [OPTIONS] [-- CLAUDE_ARGS...]

OPTIONS:
    -h, --help          Show this help message and exit
    -u, --url <url>     LM Studio base URL (default: http://localhost:1234)

ENVIRONMENT:
    LM_STUDIO_BASE_URL  Override the default LM Studio URL

EXAMPLES:
    ./claude-local
    LM_STUDIO_BASE_URL=http://localhost:5678 ./claude-local

EOF
}


printf "Using LM Studio at %s\n" "$ANTHROPIC_BASE_URL"
printf "%s\n" "============================================================"

# Query available models
response=$(curl -sf --max-time 5 "${ANTHROPIC_BASE_URL}/v1/models" 2>/dev/null) || {
    # shellcheck disable=SC2059
    printf "${ERROR} Could not connect to LM Studio at %s\n" "$ANTHROPIC_BASE_URL" >&2
    printf "Make sure LM Studio is running and accessible.\n" >&2
    exit 1
}

# Extract model IDs into array (bash 3.2 compatible)
models=()
while IFS= read -r model_id; do
    models+=("$model_id")
done < <(printf '%s' "$response" | jq -r '.data[].id')

if [[ ${#models[@]} -eq 0 ]]; then
    # shellcheck disable=SC2059
    printf "${ERROR} No models found.\n" >&2
    exit 1
fi

# Interactive menu implementation, taken from:
# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
# and bent slightly for my own purposes.
function select_option {
    options=("$@")
    
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt in "${options[@]}"; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt in "${options[@]}"; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    selected_option=${options[$selected]}
}


# Let user select a model
printf "\nAvailable Models:\n"
select_option "${models[@]}"
model=$selected_option

claude_args=()

# The default system prompt claude code injects is something like 12k tokens,
# which doesn't work great with some smaller models.
# ref: https://github.com/Piebald-AI/claude-code-system-prompts

# this is probably overkill. It seems to cause some confusion about the built-in tools.
#claude_args+=("--bare")

# Replacement for the default system prompt
#REPLACEMENT_SYSTEM_PROMPT=$(<<EOF
#You are a coding assistant.
#EOF
#)
#claude_args+=("--system-prompt" "$REPLACEMENT_SYSTEM_PROMPT")
echo "model is $model"

printf "\nLaunching Claude Code with model: %s\n" "$model"
claude_args+=("--model" "$model")

#echo running claude "${claude_args[@]}" "$@" 
exec claude "${claude_args[@]}" "$@"
