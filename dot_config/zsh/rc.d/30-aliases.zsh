# 30-aliases.zsh — System aliases, modern tool replacements, git shortcuts

# ── 1. Modern Tool Replacements ──────────────────────────────────────────────
if (( $+commands[eza] )); then
    alias ls='eza --icons --git --group-directories-first'
    alias ll='eza -lh --icons --git --group-directories-first'
    alias la='eza -la --icons --git --group-directories-first'
    alias lt='eza -lT --level=2 --icons'
    alias tree='eza --tree --icons --git-ignore'
fi

if (( $+commands[bat] )); then
    alias cat='bat --paging=never'
    alias preview='bat --style=numbers --color=always'
fi

(( $+commands[fd] )) && alias find='fd'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[procs] )) && alias ps='procs'
(( $+commands[btm] )) && alias top='btm'

if (( $+commands[rg] )); then
    function grep() { rg "$@" }
fi

# ── 2. Navigation ────────────────────────────────────────────────────────────
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias reload="source ~/.zshrc"
alias down="cd ~/Downloads"
alias dev="cd ~/Developer"
alias doc="cd ~/Documents"
alias ip="ipconfig getifaddr en0"

# ── 3. Git (Essential OMZ set) ───────────────────────────────────────────────
alias g="git"
(( $+commands[lazygit] )) && alias lg='lazygit'

# Status & Diff
alias gst="git status"
alias gd="git diff"
alias gds="git diff --staged"

# Branching
alias gco="git checkout"
alias gcb="git checkout -b"
alias gb="git branch"
alias gbd="git branch -d"
alias gm="git merge"

# Add & Commit
alias ga="git add"
alias gaa="git add --all"
alias gc="git commit -v"
alias gcmsg="git commit -m"
alias gcam="git commit -a -m"
alias gamend="git commit --amend"

# Pull & Push
alias gl="git pull"
alias gp="git push"
alias gpsup='git push --set-upstream origin $(git branch --show-current)'
alias gpf="git push --force-with-lease"

# Log
alias glog="git log --oneline --decorate --graph"
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"

# Stash
alias gsta="git stash push"
alias gstp="git stash pop"
alias gstl="git stash list"

# ── 4. Package Managers ──────────────────────────────────────────────────────
(( $+commands[pnpm] )) && alias p="pnpm"
alias brewst="brew bundle --file=~/.local/share/chezmoi/Brewfile 2>/dev/null || brew list"

# ── 5. Misc Tools ────────────────────────────────────────────────────────────
(( $+commands[ast-grep] )) && alias sg='ast-grep'
alias claude-conductor='"$HOME/Library/Application Support/com.conductor.app/bin/claude"'
alias pymobiledevice3="source ~/.venv/bin/activate && python -m pymobiledevice3"

# ── 6. mgrep (semantic search) ───────────────────────────────────────────────
if (( $+commands[mgrep] )); then
    alias mg='mgrep search'
    alias mgc='mgrep search -c'
    alias mga='mgrep search -a'
    alias mgw='mgrep search -w'
    alias mgwa='mgrep search -w -a'
    alias mgs='mgrep search -s'
    function mgsearch() { mgrep search -c -m 20 "$@" }
    function webai() { mgrep search -w -a "$@" }
fi
