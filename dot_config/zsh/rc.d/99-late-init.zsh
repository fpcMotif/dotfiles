# 99-late-init.zsh — Late tool init, local overrides, final startup tasks

# ── Zoxide (must be last for cd override) ────────────────────────────────────
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd z)"
fi

# ── AI Tools Update Check (background) ──────────────────────────────────────
if [[ -x "$HOME/.local/bin/update-ai-tools" ]]; then
  ("$HOME/.local/bin/update-ai-tools" --check >/dev/null 2>&1 &)
fi

# ── cmux Helpers ─────────────────────────────────────────────────────────────
_CMUX_ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
if [[ -r $_CMUX_ZDOTDIR/cmux.zsh ]]; then
  source $_CMUX_ZDOTDIR/cmux.zsh
else
  log_debug "Skipping cmux init: $_CMUX_ZDOTDIR/cmux.zsh not readable"
fi
unset _CMUX_ZDOTDIR

# ── Consolidate Functions ────────────────────────────────────────────────────
if [[ -f $ZDOTDIR/function.zsh ]]; then
  source $ZDOTDIR/function.zsh
else
  log_debug "Skipping function.zsh: $ZDOTDIR/function.zsh not found"
fi

# ── Load Local Overrides (last, highest priority) ────────────────────────────
if [[ -r $HOME/.zshrc.local ]]; then
  source $HOME/.zshrc.local
else
  log_debug "Skipping local overrides: $HOME/.zshrc.local not readable"
fi
