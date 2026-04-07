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
[[ -r $_CMUX_ZDOTDIR/cmux.zsh ]] && source $_CMUX_ZDOTDIR/cmux.zsh
unset _CMUX_ZDOTDIR

# ── Consolidate Functions ────────────────────────────────────────────────────
[[ -f $ZDOTDIR/function.zsh ]] && source $ZDOTDIR/function.zsh

# ── Load Local Overrides (last, highest priority) ────────────────────────────
[[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local
