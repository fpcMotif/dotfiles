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
path=(
  $HOME/.local/bin
  /opt/zerobrew/prefix/bin
  /opt/nanobrew/prefix/bin
  /opt/homebrew/bin
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

# ── Terminfo ─────────────────────────────────────────────────────────────────
export TERMINFO="$HOME/.terminfo"
typeset -aU _terminfo_dirs
_terminfo_dirs=(
  $HOME/.terminfo
  /Applications/kitty.app/Contents/Resources/kitty/terminfo
  /Applications/kitty.app/Contents/Resources/terminfo
  /opt/zerobrew/prefix/opt/ncurses/share/terminfo
  /usr/share/terminfo
  ${(s/:/)TERMINFO_DIRS}
)
_terminfo_dirs=(${_terminfo_dirs:#})
(( ${#_terminfo_dirs[@]} > 0 )) && export TERMINFO_DIRS="${(j/:/)_terminfo_dirs}"
unset _terminfo_dirs

alias sudo='sudo -E'

# ── Build & SDK Flags (auto-detect active brew prefix) ───────────────────────
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
if [[ -z "$SDKROOT" ]]; then
  export SDKROOT="$(xcrun --show-sdk-path 2>/dev/null)"
fi
[[ -n "$SDKROOT" ]] && {
  export CFLAGS="-isysroot $SDKROOT $CFLAGS"
  export CPPFLAGS="-isysroot $SDKROOT $CPPFLAGS"
}

# ── Theme Settings ───────────────────────────────────────────────────────────
export BAT_THEME="Catppuccin-macchiato"
export HOMEBREW_NO_ANALYTICS=1
export RANGER_LOAD_DEFAULT_RC="FALSE"
export PNPM_HOME=$HOME/Library/pnpm
export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst
export POWERLINE_NERD_FONTS=1
