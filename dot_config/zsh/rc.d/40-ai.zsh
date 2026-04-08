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
    python3 -c "import json; print(json.load(open('$HOME/.config/climode.json')).get('$1','proxy'))" 2>/dev/null
  else
    echo "proxy"
  fi
}

_proxy_cmd() {
  local tool="$1"
  if [[ "$(_climode_get "$tool")" == "direct" ]]; then
    if [[ "$tool" == "pi" ]]; then
      ( _unset_ai_env; command "$@" )
    else
      command "$@"
    fi
  else
    with-cliproxy "$@"
  fi
}

opencode() {
  case "${1:-}" in
    auth) (_unset_ai_env; command opencode "$@") ;;
    *) _proxy_cmd opencode "$@" ;;
  esac
}

amp() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command amp "$@") ;;
    *) _proxy_cmd amp "$@" ;;
  esac
}

crush() { _proxy_cmd crush "$@" }

droid() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command droid "$@") ;;
    *) _proxy_cmd droid "$@" ;;
  esac
}

pi() {
  case "${1:-}" in
    login|logout|whoami|auth) (_unset_ai_env; command pi "$@") ;;
    *) _proxy_cmd pi "$@" ;;
  esac
}
