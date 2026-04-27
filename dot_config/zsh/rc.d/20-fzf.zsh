# 20-fzf.zsh — FZF configuration, keybindings, and helper functions

# ── FZF Init ─────────────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

_fzf_shell_dir=''

# 1) Prefer shell integration adjacent to the fzf binary, if available
if _fzf_bin="$(command -v fzf 2>/dev/null)"; then
  for _candidate in \
    "${_fzf_bin:h}/../share/fzf/shell" \
    "${_fzf_bin:h}/../share/fzf"; do
    if [[ -d "$_candidate" ]]; then
      _fzf_shell_dir="$_candidate"
      break
    fi
  done
fi

# 2) Probe common Nix profile locations
if [[ -z "$_fzf_shell_dir" ]]; then
  for _candidate in \
    "$HOME/.nix-profile/share/fzf/shell" \
    "$HOME/.nix-profile/share/fzf" \
    "/nix/var/nix/profiles/default/share/fzf/shell" \
    "/nix/var/nix/profiles/default/share/fzf"; do
    if [[ -d "$_candidate" ]]; then
      _fzf_shell_dir="$_candidate"
      break
    fi
  done
fi

# 3) Try known brew prefixes (zerobrew > homebrew > nanobrew)
if [[ -z "$_fzf_shell_dir" ]]; then
  for _fzf_prefix in /opt/zerobrew/prefix /opt/homebrew /opt/nanobrew/prefix; do
    if [[ -d "$_fzf_prefix/opt/fzf/shell" ]]; then
      _fzf_shell_dir="$_fzf_prefix/opt/fzf/shell"
      break
    fi
  done
fi

if [[ -n "$_fzf_shell_dir" ]]; then
  [[ -f "$_fzf_shell_dir/completion.zsh" ]] && source "$_fzf_shell_dir/completion.zsh" 2>/dev/null
  [[ -f "$_fzf_shell_dir/key-bindings.zsh" ]] && source "$_fzf_shell_dir/key-bindings.zsh" 2>/dev/null
fi

unset _fzf_bin _fzf_shell_dir _fzf_prefix _candidate

# ── Default Options (Nerd Font + modern palette) ─────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border --ansi \
  --prompt='󰭎 ' --pointer='󰁔 ' --marker='󰄬 ' \
  --color=fg:-1,bg:-1,hl:cyan,fg+:white,bg+:black,hl+:cyan \
  --color=info:yellow,prompt:cyan,pointer:green,marker:yellow,spinner:green,header:cyan"

# ── CTRL-T: File search with bat preview ─────────────────────────────────────
export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git --color=always'
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# ── ALT-C: Directory search with eza tree preview ────────────────────────────
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --color=always'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always --no-quotes {}'"

# ── Helper Functions ─────────────────────────────────────────────────────────

# Find in files — interactive content search
fif() {
  (( $# )) || return
  rg --files-with-matches --no-messages -- "$1" | \
    FIF_QUERY="$1" fzf \
      --prompt='󰈞 ' \
      --preview 'rg --ignore-case --pretty --context 10 -- "$FIF_QUERY" {}'
}

# Interactive git branch switching with commit preview
fgb() {
  local branches branch
  branches=$(git branch --all | grep -v 'HEAD') &&
  branch=$(echo "$branches" | fzf --prompt='󱔎 ' --height 50% --layout=reverse --border \
    --preview "git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%h %C(magenta)%ad %C(cyan)%an %Creset%s' {1} | head -n 20") &&
  git checkout "$(echo "$branch" | sed 's/.* //; s#remotes/[^/]*/##')"
}

# Interactive git log viewer
fgl() {
  git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --prompt='󰊚 ' --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
    --bind "ctrl-m:execute:
      (grep -o '[a-f0-9]\{7\}' | head -1 |
      xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
      {}
FZF-EOF" \
    --preview "grep -o '[a-f0-9]\{7\}' <<< {} | xargs git show --color=always"
}

# Interactive process killer
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf --prompt='󰆙 ' -m | awk '{print $2}')
  [[ -n "$pid" ]] && echo "$pid" | xargs -r kill "-${1:-9}"
}
