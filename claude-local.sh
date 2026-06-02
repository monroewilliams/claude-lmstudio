#!/usr/bin/env bash
# Local inference server model selector
# Connects to a local inference server (oMLX, LM Studio, llama-server, etc.) endpoint, 
# queries available models, and launches Claude Code with the selected model.

set -euo pipefail

trap 'printf "${ERROR} at or near line %s:\n\t%s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

function cleanup() {
    stty sane
    printf "\n"
}

ERROR="\e[0;31m[Error]\e[0m"

if [[ -n "${CLAUDE_LOCAL_BASE_URL-}" ]]; then
    # If set, CLAUDE_LOCAL_BASE_URL overrides ANTHROPIC_BASE_URL set in the environment
    export ANTHROPIC_BASE_URL="${CLAUDE_LOCAL_BASE_URL}"
elif [[ -n "${ANTHROPIC_BASE_URL-}" ]]; then
    # ANTHROPIC_BASE_URL was set, leave it alone.
    true
else
    # neither of these were set, use a default endpoint.
    export ANTHROPIC_BASE_URL="http://localhost:1234"
fi

if [[ -n "${CLAUDE_LOCAL_AUTH_TOKEN-}" ]]; then
    # If set, CLAUDE_LOCAL_AUTH_TOKEN overrides ANTHROPIC_AUTH_TOKEN set in the environment
    export ANTHROPIC_AUTH_TOKEN="${CLAUDE_LOCAL_AUTH_TOKEN}"
elif [[ -n "${ANTHROPIC_AUTH_TOKEN-}" ]]; then
    # ANTHROPIC_AUTH_TOKEN was set, leave it alone.
    true
elif [ "$(uname)" = "Darwin" ] && command -v security >/dev/null 2>&1; then
    # No auth token from environment variables, and we're on macOS.
    # Check for a key in an unlocked keychain with a username matching the base url.
    KEYCHAIN_AUTH_TOKEN=$(security find-generic-password -s "claude-local" -a "${ANTHROPIC_BASE_URL}" -w 2>/dev/null || true)
    if [[ -n "${KEYCHAIN_AUTH_TOKEN-}" ]]; then
        export ANTHROPIC_AUTH_TOKEN="${KEYCHAIN_AUTH_TOKEN}"
    fi
fi

if [[ -z "${ANTHROPIC_AUTH_TOKEN-}" ]]; then
    # claude needs ANTHROPIC_AUTH_TOKEN to be non-empty, or it will think you're not logged in.
    # This isn't an actual auth token. Extra points if you get this reference. ;)
    export ANTHROPIC_AUTH_TOKEN="swordfish"
fi

printf 'using base url: %s\n' "${ANTHROPIC_BASE_URL}"
# useful when debugging the script, but exposes the auth token.
#printf 'using auth token: %s\n' "${ANTHROPIC_AUTH_TOKEN}"

help() {
    cat <<EOF
claude-local

Connects to an LM Studio or llama-server instance, queries available models,
and launches Claude Code with the selected model.

USAGE:
    ./claude-local [CLAUDE_ARGS...]

ENVIRONMENT:
    CLAUDE_LOCAL_BASE_URL  Override the default endpoint URL
    CLAUDE_LOCAL_AUTH_TOKEN Provide an auth token for the endpoint
    
EXAMPLES:
    ./claude-local
    CLAUDE_LOCAL_BASE_URL=http://localhost:5678 ./claude-local
    
EOF
}

# Interactive menu implementation, taken from:
# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
# and bent slightly for my own purposes.
function select_option {
    options=("$@")
    
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "${ESC}[?25h"; }
    cursor_blink_off() { printf "${ESC}[?25l"; }
    cursor_to()        { printf "${ESC}[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  ${ESC}[7m $1 ${ESC}[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { 
                         read -s -n1 key 2>/dev/null
                         if [[ $key == ${ESC} ]]; then
                             # Escape or escape sequence — try to read the remaining [A / [B in one shot, with 100ms timeout
                             stty -echo -icanon min 0 time 1
                             seq=$(dd bs=1 count=2 2>/dev/null)
                             if [[ "$seq" == '[A' ]]; then
                                 echo up
                             elif [[ "$seq" == '[B' ]]; then
                                 echo down
                             else
                                 # Lone escape key (sequence read timed out)
                                 echo escape;
                             fi
                             stty echo icanon 
                         else
                             # Got any other character — treat as Enter
                             echo enter;
                         fi
                       }

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
            escape) cursor_to $lastrow; printf "\n"; cursor_blink_on; cleanup; exit 0;;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    printf "\n"
    cursor_blink_on

    selected_option=$selected
}

models=()
prompts=()

function models_omlx() {
    # Read models from the oMLX models/status endpoint
    # echo "trying ${ANTHROPIC_BASE_URL}/v1/models/status"
    response=$(curl -v -s --fail --max-time 5 -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN-}" "${ANTHROPIC_BASE_URL}/v1/models/status" 2>/dev/null) || {
        # This request failed -- response being empty will do the right thing below.
        true
    }
    health=$(curl -v -s --fail --max-time 5 -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN-}" "${ANTHROPIC_BASE_URL}/health" 2>/dev/null) || {
        # This request failed
        true
    }
    if [[ -n "$response" ]]; then
        # output health check info
        # jq -r <<<"${health}"
        
        # extract the default model from the health check
        printf "default model: %s" $(jq -r '.default_model' <<<"${health}")
        
        # oMLX endpoint provides some rich data
        lines=$(echo "$response" | jq -r '.models[] | [.id, .max_context_window, .config_model_type, .loaded] | join(",")')
        # case-insensitive sort
        sorted=$(echo "$lines" | sort -f)
        IFS=$'\n' models=($(echo "$lines" | awk -F',' '{print $1}'))
        IFS=$'\n' prompts=($(echo "$lines" | awk -F',' '{printf "%s   (loaded:%s, type:%s window:%d)\n", $1, $4, $3, $2}'))
        
#        printf 'models: %s\n' "${models[@]}"
#        printf 'prompts: %s\n' "${prompts[@]}"

    fi
}

function models_lmstudio() {
    # Read models from the LM Studio models endpoint
    # echo "trying ${ANTHROPIC_BASE_URL}/api/v1/models"
    response=$(curl -v -s --fail --max-time 5 -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN-}" "${ANTHROPIC_BASE_URL}/api/v1/models" 2>/dev/null) || {
        # This request failed -- response being empty will do the right thing below.
        true
    }
    if [[ -n "$response" ]]; then
        # LM Studio endpoint provides some rich data
        lines=$(echo "$response" | jq -r '.models[] | [.key, .display_name, .architecture, .format] | join(",")')
        # case-insensitive sort
        sorted=$(echo "$lines" | sort -f)
        IFS=$'\n' models=($(echo "$lines" | awk -F',' '{print $1}'))
        IFS=$'\n' prompts=($(echo "$lines" | awk -F',' '{printf "%s   (key:%s, arch:%s, format:%s)\n", $2, $2, $3, $4}'))
        
#        printf 'models: %s\n' "${models[@]}"
#        printf 'prompts: %s\n' "${prompts[@]}"

    fi
}

function models_openai() {
    # Read models from OpenAI-format endpoint
    # echo "trying ${ANTHROPIC_BASE_URL}/v1/models"
    response=$(curl -v -s --fail --max-time 5 -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN-}" "${ANTHROPIC_BASE_URL}/v1/models" 2>/dev/null) || {
        # Neither endpoint worked, bail out.
        printf "${ERROR} Could not connect to endpoint at %s\n" "$ANTHROPIC_BASE_URL" >&2
        exit 1
    }
#    printf "response is %s", "$response"
    if [[ -n "$response" ]]; then
        # The OpenAI endpoint only provides model IDs. Just present them to the user as-is.
        lines=$(echo "$response" | jq -r '.data[] | .id')
        IFS=$'\n' models=($lines)
        prompts=("${models[@]}")
    fi
}

function select_model() {
#    printf "Using endpoint at %s\n" "$ANTHROPIC_BASE_URL"

    # Query available models
    models=()
    prompts=()

    if [[ ${#models[@]} -eq 0 ]]; then
        # First try the oMLX endpoint
        models_omlx
    fi

    if [[ ${#models[@]} -eq 0 ]]; then
        # If that didn't find anything, try the lmstudio endpoint
        models_lmstudio
    fi

    if [[ ${#models[@]} -eq 0 ]]; then
        # Neither of those worked, fall back to the OpenAI endpoint.
        models_openai
    fi

    if [[ ${#models[@]} -eq 0 ]]; then
        printf "${ERROR} No models found.\n" >&2
        exit 1
    fi

    if [[ ${#models[@]} -eq 1 ]]; then
        # only one model is available, don't bother with the selector menu.
        model=${models[0]}
    else
        # Let user select a model
        printf "\nAvailable Models:\n"
        select_option "${prompts[@]}"
        model=${models[$selected_option]}
    fi
}

if [[ -z "${CLAUDE_LOCAL_MODEL-}" ]]; then
    select_model
    CLAUDE_LOCAL_MODEL="$model"
fi

claude_args=()

# Slimmed-down claude system prompt. Adapted from:
# https://spicyneuron.substack.com/p/a-mac-studio-for-local-ai-6-months
claude_prompt() {
  cat << 'EOF'
You are an interactive CLI agent specialized in software engineering. Use tools to accomplish the user's tasks.
Read the file ~/.claude/CLAUDE.md and always follow any directions it contains. These are as important as your system prompt, and must never be ignored.

# Communication
- Be direct, professional, and objective. Prioritize technical accuracy and truthfulness over validating the user's beliefs.
- Give short, concise responses in GitHub-flavored markdown.
- Use `file_path:line_number` to reference code locations.
- Prefer editing existing files. Do not create files unless absolutely necessary.

# Code Standards
- Be careful not to introduce vulnerabilities (OWASP top 10). Fix immediately if found.
- Prefer precisely scoped edits. Avoid over-engineering. No extra features, premature optimization, abstractions without good cause.
- Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs).
- Delete unused code completely. No backwards-compatibility unless asked.

# Tools
- Read files before modifying. Never propose changes to unread code.
- Bash commands run from your current working directory. No need to `cd` unless changing directories.
- Prefer separate Bash commands over `&&` chained ones.

# System
- Automatic <system-reminder> tags may appear in tool results or user messages. These bear no direct relation to the specific result or message.
- Users may configure 'hooks', shell commands that execute in response to events like tool calls. Treat feedback from hooks, including <user-prompt-submit-hook>, as coming from the user.
- The conversation has unlimited context through automatic summarization.
EOF

  local is_git="No"
  local git_info=""
  if git rev-parse --git-dir &>/dev/null; then
    is_git="Yes"
    local current_branch=$(git branch --show-current 2>/dev/null)
    local recent_commits=$(git log --oneline -5 2>/dev/null)
    git_info="${git_info}\nCurrent branch: ${current_branch}\n\nRecent commits:\n${recent_commits}"
  fi

  printf "\n<env>"
  printf "\nPlatform: %s %s" "$(uname -s)" "$(uname -r)"
  printf "\nToday's date: %s" "$(date +%Y-%m-%d)"
  printf "\n"
  printf "\nYour working directory: %s" "$PWD"
  printf "\n"
  # MBW -- this doesn't seem to be working properly for me.
#  local tree_out=$(tree -L 2 --gitignore --dirsfirst -F --noreport --prune --condense --compress 3 2>&1)
#  if  "$tree_out"  *"[error opening dir]"* ; then
    ls -F
#  else
#    printf "%s" "$tree_out"
#  fi

  printf "\nIs git repo: %s" "$is_git"
  test -n "$git_info"  && printf "%b" "$git_info"
  printf "\n</env>"
  printf "\n"
}

claude_args+=("--tools" "Bash,Glob,Grep,Read,Edit,Write, Skill")
claude_args+=("--system-prompt" "$(claude_prompt)")

printf "\nLaunching Claude Code with model: %s\n" "${CLAUDE_LOCAL_MODEL}"
# doing it this way lets you use 1M context, since it will treat it like Opus
export ANTHROPIC_DEFAULT_OPUS_MODEL="${CLAUDE_LOCAL_MODEL}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${CLAUDE_LOCAL_MODEL}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${CLAUDE_LOCAL_MODEL}"
# claude_args+=("--model" "$model")

export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

#echo running claude "${claude_args[@]}" "$@" 
claude "${claude_args[@]}" "$@"
