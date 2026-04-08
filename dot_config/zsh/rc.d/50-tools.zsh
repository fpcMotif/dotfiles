# 50-tools.zsh — Agent Browser, Bun, GHCup, Kiro, Mole, Ruby/Try integrations

# ── Chrome Canary & agent-browser ────────────────────────────────────────────
export AGENT_BROWSER_CDP_URL="http://localhost:9222"
alias canary-start='~/.local/bin/canary-debug'
ab() {
    if ! curl -s --max-time 1 "http://localhost:9222/json/version" > /dev/null 2>&1; then
        [[ -x ~/.local/bin/canary-debug ]] && ~/.local/bin/canary-debug > /dev/null 2>&1
    fi
    agent-browser "$@"
}

# ── Bun ──────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ── GHCup (Haskell) ─────────────────────────────────────────────────────────
[ -f "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

# ── Kiro ─────────────────────────────────────────────────────────────────────
[[ "$TERM_PROGRAM" == "kiro" ]] && (( $+commands[kiro] )) && {
  local _kiro_path
  _kiro_path="$(kiro --locate-shell-integration-path zsh 2>/dev/null)"
  [[ -n "$_kiro_path" && -f "$_kiro_path" ]] && . "$_kiro_path"
}

# ── Mole ─────────────────────────────────────────────────────────────────────
(( $+commands[mole] )) && {
  local _mole_comp
  _mole_comp="$(mole completion zsh 2>/dev/null)" && eval "$_mole_comp"
}

# ── Ruby/Try ─────────────────────────────────────────────────────────────────
[[ -f "$HOME/.local/try.rb" ]] && (( $+commands[ruby] )) && {
  local _try_init
  _try_init="$(ruby ~/.local/try.rb init ~/src/tries 2>/dev/null)" && eval "$_try_init"
}
