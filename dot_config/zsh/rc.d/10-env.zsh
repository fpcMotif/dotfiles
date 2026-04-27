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

# ── PATH Configuration (Deduplicated + optional roots) ──────────────────────
typeset -U path PATH

# Toggleable package-manager PATH modes
: ${USE_NIX_PROFILE:=0}
: ${USE_BREW_PATHS:=1}
: ${USE_ZEROBREW_PATHS:=1}

# Configurable path roots (can be overridden before this file is sourced)
: ${NIX_PROFILE_BIN:=$HOME/.nix-profile/bin}
: ${NIX_DEFAULT_PROFILE_BIN:=/nix/var/nix/profiles/default/bin}
: ${ZEROBREW_PREFIX_BIN:=/opt/zerobrew/prefix/bin}
: ${NANOBREW_PREFIX_BIN:=/opt/nanobrew/prefix/bin}
: ${HOMEBREW_PREFIX_BIN:=/opt/homebrew/bin}
: ${LOCAL_HOMEBREW_PREFIX_BIN:=/usr/local/bin}

_path_prepend_if_exists() {
  local candidate="$1"
  [[ -n "$candidate" && -d "$candidate" ]] && path=("$candidate" $path)
}

# General user/tooling bins
_path_prepend_if_exists "$HOME/.local/bin"
_path_prepend_if_exists "$HOME/bin"
_path_prepend_if_exists "$HOME/.bun/bin"
_path_prepend_if_exists "$HOME/.ghcup/bin"
_path_prepend_if_exists "$HOME/.cargo/bin"
_path_prepend_if_exists "$HOME/go/bin"
_path_prepend_if_exists "$HOME/.opencode/bin"
_path_prepend_if_exists "$HOME/.codeium/windsurf/bin"
_path_prepend_if_exists "$HOME/.antigravity/antigravity/bin"
_path_prepend_if_exists "$HOME/.amp/bin"
_path_prepend_if_exists "$HOME/.fabro/bin"

# Package-manager bins
(( USE_ZEROBREW_PATHS )) && {
  _path_prepend_if_exists "$ZEROBREW_PREFIX_BIN"
  _path_prepend_if_exists "$NANOBREW_PREFIX_BIN"
}
(( USE_BREW_PATHS )) && {
  _path_prepend_if_exists "$HOMEBREW_PREFIX_BIN"
  _path_prepend_if_exists "$LOCAL_HOMEBREW_PREFIX_BIN"
}
(( USE_NIX_PROFILE )) && {
  _path_prepend_if_exists "$NIX_PROFILE_BIN"
  _path_prepend_if_exists "$NIX_DEFAULT_PROFILE_BIN"
}

# Optional machine-/version-specific PATH additions belong in:
#   ~/.config/zsh/rc.local/*.zsh
for _local_env in "$HOME/.config/zsh/rc.local"/*.zsh(N); do
  source "$_local_env"
done
unset _local_env

# Strip non-existent dirs — avoids wasted lookups on 16GB M1
path=(${^path}(N-/))
unset _path_prepend_if_exists
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

# ── Build & SDK Flags (gated by package-manager mode) ───────────────────────
_pm_mode="${PACKAGE_MANAGER_MODE:-}"
if [[ -z "$_pm_mode" ]]; then
  if (( USE_NIX_PROFILE )) && [[ -d "$NIX_PROFILE_BIN" || -d "$NIX_DEFAULT_PROFILE_BIN" ]]; then
    _pm_mode="nix"
  elif [[ -d "/opt/zerobrew/prefix" ]]; then
    _pm_mode="zerobrew"
  elif [[ -d "/opt/homebrew" || -d "/usr/local/Homebrew" ]]; then
    _pm_mode="brew"
  fi
fi

_pm_root=""
case "$_pm_mode" in
  zerobrew) _pm_root="/opt/zerobrew/prefix" ;;
  brew)
    if [[ -d "/opt/homebrew" ]]; then
      _pm_root="/opt/homebrew"
    elif [[ -d "/usr/local" ]]; then
      _pm_root="/usr/local"
    fi
    ;;
  nix)
    if [[ -d "$HOME/.nix-profile" ]]; then
      _pm_root="$HOME/.nix-profile"
    elif [[ -d "/nix/var/nix/profiles/default" ]]; then
      _pm_root="/nix/var/nix/profiles/default"
    fi
    ;;
esac

if [[ -n "$_pm_root" ]]; then
  if [[ "$_pm_mode" == "nix" ]]; then
    export PKG_CONFIG_PATH="$_pm_root/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  else
    export PKG_CONFIG_PATH="$_pm_root/lib/pkgconfig:$_pm_root/opt/tcl-tk/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LDFLAGS="-L$_pm_root/lib -L$_pm_root/opt/tcl-tk/lib ${LDFLAGS:-}"
    export CPPFLAGS="-I$_pm_root/include -I$_pm_root/opt/tcl-tk/include ${CPPFLAGS:-}"
    export CFLAGS="-I$_pm_root/opt/tcl-tk/include ${CFLAGS:-}"
    export PYTHON_CONFIGURE_OPTS="--with-tcltk-includes='-I$_pm_root/opt/tcl-tk/include' --with-tcltk-libs='-L$_pm_root/opt/tcl-tk/lib -ltcl8.6 -ltk8.6'"
  fi
fi
unset _pm_mode _pm_root

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
export HOMEBREW_NO_ANALYTICS=1
export RANGER_LOAD_DEFAULT_RC="FALSE"
export PNPM_HOME=$HOME/Library/pnpm
export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst
export POWERLINE_NERD_FONTS=1
