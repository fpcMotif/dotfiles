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
  if [[ -f "$HOME/.config/climode.json" ]]; then
    if (( $+commands[jq] )); then
      jq -r --arg key "$1" '.[$key] // "proxy"' "$HOME/.config/climode.json" 2>/dev/null
    else
      python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], 'proxy'))" "$HOME/.config/climode.json" "$1" 2>/dev/null
    fi
  else
    printf -- "proxy\n"
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
