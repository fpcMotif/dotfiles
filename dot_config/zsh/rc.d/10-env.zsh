# 10-env.zsh — Environment, PATH, history, options, editor, build flags

# ── Zsh Options ──────────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_MENU COMPLETE_IN_WORD NO_BEEP PROMPT_CR
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt INTERACTIVE_COMMENTS HIST_FCNTL_LOCK HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS
unsetopt NOMATCH AUTO_REMOVE_SLASH

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=100000
SAVEHIST=100000

# ── PATH Configuration (Deduplicated) ────────────────────────────────────────
# Nix owns CLI tools. Home Manager's profile comes first; ~/.nix-profile is
# kept late as an ad-hoc scratch profile only.
typeset -U path PATH
path=(
  /etc/profiles/per-user/$USER/bin
  /run/current-system/sw/bin
  /nix/var/nix/profiles/default/bin
  $HOME/.local/bin
  /usr/local/bin
  $HOME/bin
  $HOME/.bun/bin
  $HOME/.ghcup/bin
  $HOME/.elixir-install/installs/otp/27.3.4/bin
  $HOME/.elixir-install/installs/elixir/1.18.4-otp-27/bin
  $HOME/.cargo/bin
  $HOME/go/bin
  $HOME/.opencode/bin
  $HOME/.codeium/windsurf/bin
  $HOME/.antigravity/antigravity/bin
  $HOME/.amp/bin
  $HOME/.fabro/bin
  /Applications/Obsidian.app/Contents/MacOS
  $HOME/.nix-profile/bin
  $path
)
# Strip non-existent dirs — avoids wasted lookups on 16GB M1
path=(${^path}(N-/))
export PATH

# ── CDPATH (jump to common dirs without full path) ────────────────────────────
export CDPATH=".:$HOME:$HOME/Developer:$HOME/Downloads:$HOME/Documents"

# ── Editor Setup ─────────────────────────────────────────────────────────────
if (( $+commands[hx] )); then
  export EDITOR=hx VISUAL=hx
elif (( $+commands[nvim] )); then
  export EDITOR=nvim VISUAL=nvim
else
  export EDITOR=vi VISUAL=vi
fi

alias sudo='sudo -E'

# ── SDK Flags ────────────────────────────────────────────────────────────────
# Brew-prefix auto-detection removed (brew is gone). If you need tcl-tk for
# building Python with Tk support, add `tcl tk` to home.nix and reference
# their store paths via pkg-config — `pkg-config --variable=prefix tcl`.
if [[ -z "$SDKROOT" ]]; then
  export SDKROOT="$(xcrun --show-sdk-path 2>/dev/null)"
fi
[[ -n "$SDKROOT" ]] && {
  export CFLAGS="-isysroot $SDKROOT $CFLAGS"
  export CPPFLAGS="-isysroot $SDKROOT $CPPFLAGS"
}

# ── Theme Settings ───────────────────────────────────────────────────────────
export BAT_THEME="Catppuccin-macchiato"
export EZA_CONFIG_DIR="$HOME/.config/eza"
export RANGER_LOAD_DEFAULT_RC="FALSE"
export PNPM_HOME=$HOME/Library/pnpm
export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst
export POWERLINE_NERD_FONTS=1
