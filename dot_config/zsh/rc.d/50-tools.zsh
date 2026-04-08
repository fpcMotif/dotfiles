# 50-tools.zsh — Agent Browser, Bun, GHCup, Kiro, Mole, Ruby/Try integrations

# ── Chrome Canary & agent-browser ────────────────────────────────────────────
export AGENT_BROWSER_CDP_URL="http://localhost:9222"
[[ -x ~/.local/bin/canary-debug ]] && alias canary-start='~/.local/bin/canary-debug'
ab() {
    if ! curl -s "http://localhost:9222/json/version" > /dev/null 2>&1; then
        [[ -x ~/.local/bin/canary-debug ]] && ~/.local/bin/canary-debug > /dev/null 2>&1
    fi
    (( $+commands[agent-browser] )) && agent-browser "$@"
}

# ── Bun ──────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ── GHCup (Haskell) ─────────────────────────────────────────────────────────
[ -f "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

# ── Kiro ─────────────────────────────────────────────────────────────────────
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# ── Mole ─────────────────────────────────────────────────────────────────────
(( $+commands[mole] )) && eval "$(mole completion zsh)"

# ── Ruby/Try ─────────────────────────────────────────────────────────────────
[[ -f "$HOME/.local/try.rb" ]] && eval "$(ruby ~/.local/try.rb init ~/src/tries)"
