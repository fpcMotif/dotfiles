# 40-ai.zsh — AI tool wrappers, Claude provider system, CLIProxyAPI routing

# ── Global AI Variables ──────────────────────────────────────────────────────
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
export CLAUDE_CODE_EFFORT_LEVEL=max
export CLAUDE_CODE_NO_FLICKER=1

# ── Claude Official Wrapper ──────────────────────────────────────────────────
_unset_ai_env() {
  unset ANTHROPIC_API_KEY ANTHROPIC_API_URL ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
        OPENAI_API_KEY OPENAI_API_KEY_ID OPENAI_BASE_URL OPENAI_API_BASE OPENAI_ENDPOINT \
        CODEX_API_KEY CODEX_BASE_URL GEMINI_API_KEY GEMINI_BASE_URL GOOGLE_API_KEY \
        AMP_API_KEY AMP_URL AMP_API_BASE_URL
}

cofficial() {
  (
    _unset_ai_env
    "$HOME/.local/bin/claude" --dangerously-skip-permissions "$@"
  )
}

function claude() {
  (
    _unset_ai_env
    command "$HOME/.local/bin/claude" "$@"
  )
}

cc() {
  (
    _unset_ai_env
    "$HOME/.local/bin/claude" --dangerously-skip-permissions "$@"
  )
}

# ── Other AI CLI Wrappers ────────────────────────────────────────────────────
alias gy='gemini -y'
alias oc='opencode'
alias cdx='codex-safe'
alias cct='cmux claude-teams --dangerously-skip-permissions'
codex() { codex-safe "$@" }

# ── CLIProxyAPI Routing ──────────────────────────────────────────────────────
export CLIPROXY_BASE_URL="${CLIPROXY_BASE_URL:-http://127.0.0.1:8317}"
export CLIPROXY_CONFIG="${CLIPROXY_CONFIG:-$HOME/CLIProxyAPI/config.yaml}"

_climode_get() {
  local default_val="proxy"
  local config_file="$HOME/.config/climode.json"
  if [[ -f "$config_file" ]]; then
    if _has jq; then
      jq -r --arg k "$1" '.[$k] // "proxy"' "$config_file" 2>/dev/null || printf -- "%s\n" "$default_val"
    elif _has python3; then
      python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], 'proxy'))" "$config_file" "$1" 2>/dev/null || printf -- "%s\n" "$default_val"
    else
      printf -- "%s\n" "$default_val"
    fi
  else
    printf -- "%s\n" "$default_val"
  fi
}

opencode() {
  case "${1:-}" in
    auth) (_unset_ai_env; command opencode "$@") ;;
    *) if [[ "$(_climode_get opencode)" == "direct" ]]; then command opencode "$@"; else with-cliproxy opencode "$@"; fi ;;
  esac
}

amp() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command amp "$@") ;;
    *) if [[ "$(_climode_get amp)" == "direct" ]]; then command amp "$@"; else with-cliproxy amp "$@"; fi ;;
  esac
}

crush() { if [[ "$(_climode_get crush)" == "direct" ]]; then command crush "$@"; else with-cliproxy crush "$@"; fi }

droid() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command droid "$@") ;;
    *) if [[ "$(_climode_get droid)" == "direct" ]]; then command droid "$@"; else with-cliproxy droid "$@"; fi ;;
  esac
}

pi() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command pi "$@") ;;
    *) if [[ "$(_climode_get pi)" == "direct" ]]; then (_unset_ai_env; command pi "$@"); else with-cliproxy pi "$@"; fi ;;
  esac
}
