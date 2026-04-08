# 20-fzf.zsh — FZF configuration, keybindings, and helper functions

# ── FZF Init ─────────────────────────────────────────────────────────────────
_source_if_exists ~/.fzf.zsh
_FZF_BREW_PREFIX=$(brew --prefix 2>/dev/null)
if [[ -n "$_FZF_BREW_PREFIX" ]]; then
  _source_if_exists "$_FZF_BREW_PREFIX/opt/fzf/shell/completion.zsh"
  _source_if_exists "$_FZF_BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi
unset _FZF_BREW_PREFIX

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
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"

# ── Helper Functions ─────────────────────────────────────────────────────────

# Find in files — interactive content search
fif() {
  (( $# )) || return
  rg --files-with-matches --no-messages "$1" | fzf \
    --prompt='󰈞 ' \
    --preview "rg --ignore-case --pretty --context 10 '$1' {}"
}

# Interactive git branch switching with commit preview
fgb() {
  local branches branch
  branches=$(git branch --all | grep -v 'HEAD') &&
  branch=$(echo "$branches" | fzf --prompt='󱔎 ' --height 50% --layout=reverse --border \
    --preview "git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%h %C(magenta)%ad %C(cyan)%an %Creset%s' {1} | head -n 20") &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
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
  [[ -n "$pid" ]] && echo $pid | xargs kill -${1:-9}
}
