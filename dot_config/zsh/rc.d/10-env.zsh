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
typeset -U path PATH
typeset -a _dotfiles_nix_bins _dotfiles_brew_bins _dotfiles_bins
_dotfiles_nix_bins=(
  $HOME/.nix-profile/bin
  /etc/profiles/per-user/$USER/profile/bin
  /nix/var/nix/profiles/default/bin
  /run/current-system/sw/bin
)
_dotfiles_brew_bins=(
  /opt/zerobrew/prefix/bin
  /opt/nanobrew/prefix/bin
  /opt/homebrew/bin
)
case "${DOTFILES_PKG_STACK:-auto}" in
  nix) _dotfiles_bins=(${_dotfiles_nix_bins[@]}) ;;
  brew) _dotfiles_bins=(${_dotfiles_brew_bins[@]}) ;;
  hybrid|auto|*) _dotfiles_bins=(${_dotfiles_nix_bins[@]} ${_dotfiles_brew_bins[@]}) ;;
esac
path=(
  $HOME/.local/bin
  ${_dotfiles_bins[@]}
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
  $path
)
# Strip non-existent dirs — avoids wasted lookups on 16GB M1
path=(${^path}(N-/))
export PATH
unset _dotfiles_nix_bins _dotfiles_brew_bins _dotfiles_bins

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

# ── Build & SDK Flags (configurable: nix/brew/auto) ──────────────────────────
_toolchain_flavor="${DOTFILES_TOOLCHAIN_FLAVOR:-auto}"
if [[ "$_toolchain_flavor" == "auto" ]]; then
  if [[ "${DOTFILES_PKG_STACK:-auto}" == "nix" ]]; then
    _toolchain_flavor="nix"
  else
    _toolchain_flavor="brew"
  fi
fi

if [[ "$_toolchain_flavor" == "brew" ]]; then
  _brew_prefix=""
  for _bp in /opt/zerobrew/prefix /opt/homebrew /opt/nanobrew/prefix; do
    [[ -d "$_bp/lib" ]] && { _brew_prefix="$_bp"; break; }
  done
  if [[ -n "$_brew_prefix" ]]; then
    export PKG_CONFIG_PATH="$_brew_prefix/lib/pkgconfig:$_brew_prefix/opt/tcl-tk/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-L$_brew_prefix/lib -L$_brew_prefix/opt/tcl-tk/lib"
    export CPPFLAGS="-I$_brew_prefix/include -I$_brew_prefix/opt/tcl-tk/include"
    export CFLAGS="-I$_brew_prefix/opt/tcl-tk/include"
    export PYTHON_CONFIGURE_OPTS="--with-tcltk-includes='-I$_brew_prefix/opt/tcl-tk/include' --with-tcltk-libs='-L$_brew_prefix/opt/tcl-tk/lib -ltcl8.6 -ltk8.6'"
  fi
  unset _brew_prefix _bp
fi

if [[ "$OSTYPE" == darwin* && -z "$SDKROOT" ]]; then
  export SDKROOT="$(xcrun --show-sdk-path 2>/dev/null)"
fi
[[ -n "$SDKROOT" ]] && {
  export CFLAGS="-isysroot $SDKROOT $CFLAGS"
  export CPPFLAGS="-isysroot $SDKROOT $CPPFLAGS"
}
unset _toolchain_flavor

# ── Theme Settings ───────────────────────────────────────────────────────────
export BAT_THEME="Catppuccin-macchiato"
export EZA_CONFIG_DIR="$HOME/.config/eza"
export HOMEBREW_NO_ANALYTICS=1
export RANGER_LOAD_DEFAULT_RC="FALSE"
export PNPM_HOME=$HOME/Library/pnpm
export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst
export POWERLINE_NERD_FONTS=1
