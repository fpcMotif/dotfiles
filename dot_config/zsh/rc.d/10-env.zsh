# 10-env.zsh — Environment, PATH, history, options, editor, build flags
# Interactive/session owner for shell UX environment.
# Keep .zshenv limited to minimal universal exports; if Home Manager adopts env,
# prefer Nix-generated shared vars and keep this file focused on interactive-only behavior.

# ── Zsh Options ──────────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_MENU COMPLETE_IN_WORD NO_BEEP PROMPT_CR
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt INTERACTIVE_COMMENTS HIST_FCNTL_LOCK HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS
unsetopt NOMATCH AUTO_REMOVE_SLASH
KEYTIMEOUT=1  # interactive key-sequence responsiveness
HISTORY_SUBSTRING_SEARCH_PREFIXED=1  # interactive history-substring-search behavior

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

alias sudo='sudo -E'

# ── Interactive FZF Defaults (UI/preview behavior belongs in rc.d) ──────────
__tree_ignore="-I '.git' -I '*.py[co]' -I '__pycache__'"
__fd_command="-L -H --no-ignore-vcs ${__tree_ignore//-I/-E}"
export FZF_DEFAULT_COMMAND="fd $__fd_command"
export FZF_DEFAULT_OPTS="
--reverse --ansi --no-multi
--bind=ctrl-u:up,ctrl-e:down,ctrl-n:backward-char,ctrl-i:forward-char,ctrl-b:backward-word,ctrl-h:forward-word
--border --color=dark
--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
"
if [[ -v __FZF_PREVIEW ]]; then
  unset __FZF_PREVIEW
  FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
--preview='(
  bat --color=always {} ||
  tree -ahpCL 3 $__tree_ignore {}
) 2>/dev/null | head -n 100'"
fi
unset __tree_ignore __fd_command

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

# ── Session/UI Environment (single owner: rc.d/10-env.zsh) ──────────────────
# These are intentionally *not* duplicated in .zshenv.
export BAT_THEME="Catppuccin-macchiato"
export EZA_CONFIG_DIR="$HOME/.config/eza"
export HOMEBREW_NO_ANALYTICS=1
export RANGER_LOAD_DEFAULT_RC="FALSE"
export PNPM_HOME=$HOME/Library/pnpm
export LESSKEYIN=$HOME/.config/less/.lesskey
export LESSHISTFILE=$HOME/.config/less/.lesshst
export POWERLINE_NERD_FONTS=1
