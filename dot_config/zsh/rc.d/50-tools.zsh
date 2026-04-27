# 50-tools.zsh — Agent Browser, Bun, GHCup, Kiro, Mole, Ruby/Try integrations

# ── Chrome Canary & agent-browser ────────────────────────────────────────────
export AGENT_BROWSER_CDP_URL="http://localhost:9222"
alias canary-start='~/.local/bin/canary-debug'
ab() {
    if (( ! $+commands[curl] )); then
        log_debug "Skipping agent-browser bootstrap check: curl not found"
    elif ! curl -s "http://localhost:9222/json/version" > /dev/null 2>&1; then
        if [[ -x "$HOME/.local/bin/canary-debug" ]]; then
            "$HOME/.local/bin/canary-debug" > /dev/null 2>&1
        else
            log_debug "Skipping canary bootstrap: $HOME/.local/bin/canary-debug not executable"
        fi
    fi
    if (( $+commands[agent-browser] )); then
      agent-browser "$@"
    else
      log_debug "Skipping agent-browser launch: command not found"
      return 127
    fi
}

# ── Bun ──────────────────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# ── GHCup (Haskell) ─────────────────────────────────────────────────────────
[ -f "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

# ── Kiro ─────────────────────────────────────────────────────────────────────
if [[ "$TERM_PROGRAM" == "kiro" ]]; then
  if (( $+commands[kiro] )); then
    _kiro_integration_path="$(kiro --locate-shell-integration-path zsh 2>/dev/null)"
    if [[ -n "$_kiro_integration_path" && -r "$_kiro_integration_path" ]]; then
      . "$_kiro_integration_path"
    else
      log_debug "Skipping kiro shell integration: path not readable"
    fi
    unset _kiro_integration_path
  else
    log_debug "Skipping kiro shell integration: command not found"
  fi
fi

# ── Mole ─────────────────────────────────────────────────────────────────────
(( $+commands[mole] )) && eval "$(mole completion zsh)"

# ── Ruby/Try ─────────────────────────────────────────────────────────────────
if [[ -f "$HOME/.local/try.rb" ]]; then
  if (( $+commands[ruby] )); then
    eval "$(ruby ~/.local/try.rb init ~/src/tries)"
  else
    log_debug "Skipping try.rb init: ruby not found"
  fi
else
  log_debug "Skipping try.rb init: $HOME/.local/try.rb not found"
fi
