# 00-init.zsh — Plugin manager + core tool initialization
# Loaded first: sheldon plugins, post-plugin keybindings, starship prompt

# ── Helper Functions ────────────────────────────────────────────────────────
_has() { (( $+commands[$1] )) }
_source_if_exists() { [[ -r "$1" ]] && source "$1" }

# ── Plugin Manager (sheldon) ────────────────────────────────────────────────
eval "$(sheldon source)"

setopt HIST_IGNORE_ALL_DUPS
bindkey -e
WORDCHARS=${WORDCHARS//[\/]}

# Post-plugin keybindings (history-substring-search)
zmodload -F zsh/terminfo +p:terminfo
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key

# ── Starship Prompt ─────────────────────────────────────────────────────────
if _has starship; then
  eval "$(starship init zsh)"
fi
