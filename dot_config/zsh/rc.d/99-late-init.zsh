# 99-late-init.zsh — Late tool init, local overrides, final startup tasks

# ── Zoxide (must be last for cd override) ────────────────────────────────────
if _has zoxide; then
  eval "$(zoxide init zsh --cmd z)"
fi

# ── AI Tools Update Check (background) ──────────────────────────────────────
if [[ -x "$HOME/.local/bin/update-ai-tools" ]]; then
  ("$HOME/.local/bin/update-ai-tools" --check >/dev/null 2>&1 &)
fi

# ── cmux Helpers ─────────────────────────────────────────────────────────────
_CMUX_ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
_source_if_exists "$_CMUX_ZDOTDIR/cmux.zsh"
unset _CMUX_ZDOTDIR

# ── Consolidate Functions ────────────────────────────────────────────────────
_source_if_exists "$ZDOTDIR/function.zsh"

# ── Load Local Overrides (last, highest priority) ────────────────────────────
_source_if_exists "$HOME/.zshrc.local"
