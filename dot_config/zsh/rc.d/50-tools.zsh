# 50-tools.zsh — Agent Browser, Bun, GHCup, Kiro, Mole, Ruby/Try integrations

# ── Chrome Canary & agent-browser ────────────────────────────────────────────
export AGENT_BROWSER_CDP_URL="http://localhost:9222"
alias canary-start='~/.local/bin/canary-debug'
ab() {
    if ! curl -s "http://localhost:9222/json/version" > /dev/null 2>&1; then
        ~/.local/bin/canary-debug > /dev/null 2>&1
    fi
    agent-browser "$@"
}

# ── Bun ──────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
_source_if_exists "$BUN_INSTALL/_bun"
_source_if_exists "$HOME/.bun/_bun"

# ── GHCup (Haskell) ─────────────────────────────────────────────────────────
_source_if_exists "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

# ── Kiro ─────────────────────────────────────────────────────────────────────
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# ── Mole ─────────────────────────────────────────────────────────────────────
_has mole && eval "$(mole completion zsh)"

# ── Ruby/Try ─────────────────────────────────────────────────────────────────
[[ -f "$HOME/.local/try.rb" ]] && eval "$(ruby ~/.local/try.rb init ~/src/tries)"
