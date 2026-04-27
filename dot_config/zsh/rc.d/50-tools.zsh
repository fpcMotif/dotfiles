# 50-tools.zsh — Bun, GHCup, Kiro, Mole, Ruby/Try integrations

# Machine-specific debug/browser aliases belong in 90-host.zsh or 91-local.zsh.
# Example: AGENT_BROWSER_CDP_URL, canary-start, and ab() wrapper.

# ── Bun ──────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# ── GHCup (Haskell) ─────────────────────────────────────────────────────────
[ -f "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

# ── Kiro ─────────────────────────────────────────────────────────────────────
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# ── Mole ─────────────────────────────────────────────────────────────────────
(( $+commands[mole] )) && eval "$(mole completion zsh)"

# ── Ruby/Try ─────────────────────────────────────────────────────────────────
[[ -f "$HOME/.local/try.rb" ]] && eval "$(ruby ~/.local/try.rb init ~/src/tries)"
