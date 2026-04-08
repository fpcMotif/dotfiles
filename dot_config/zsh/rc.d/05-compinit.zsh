# 05-compinit.zsh — Zsh completion system

zmodload zsh/complist
autoload -Uz compinit edit-command-line; zle -N edit-command-line

# Only rebuild completion dump once per day
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Completion styling
zstyle ":completion:*:*:*:*:*" menu select
zstyle ":completion:*" use-cache yes
zstyle ":completion:*" special-dirs true
zstyle ":completion:*" squeeze-slashes true
zstyle ":completion:*" file-sort change
zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"

# Tabtab (pnpm)
_source_if_exists "$ZDOTDIR/tabtab/pnpm.zsh"
