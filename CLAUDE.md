# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## What This Repo Is

A [chezmoi](https://chezmoi.io) dotfiles repository for macOS. Files here are managed by chezmoi and applied to `$HOME`. The `dot_` prefix maps to `.` (e.g., `dot_zshrc` -> `~/.zshrc`), `dot_config/` maps to `~/.config/`, and `symlink_` prefix creates symlinks.

## Common Commands

```sh
chezmoi apply          # Apply dotfiles to $HOME
chezmoi update         # Pull latest & apply
chezmoi diff           # Preview changes before applying
chezmoi edit ~/.zshrc  # Edit a managed file (opens in $EDITOR, applies on save)
chezmoi add ~/.some-config  # Add a new file to be managed
chezmoi cd             # cd into the chezmoi source directory
```

## Architecture

### File Naming Conventions

- `dot_*` -> `.` prefix in `$HOME` (e.g. `dot_zprofile` -> `~/.zprofile`)
- `dot_config/` -> `~/.config/`
- `dot_claude/` -> `~/.claude/`
- `symlink_*` -> creates a symlink (e.g. `symlink_dot_zshrc` -> `~/.zshrc` symlink)
- `.chezmoiignore` excludes secrets and machine-specific files

### Zsh Modular Configuration

Loaded by `dot_config/zsh/dot_zshrc` -> `rc.d/*.zsh` in numeric order:

| File | Purpose |
|------|---------|
| `00-init.zsh` | Sheldon plugins + Starship prompt |
| `05-compinit.zsh` | Zsh completion system (24h cache) |
| `10-env.zsh` | PATH, history, editor, build flags |
| `20-fzf.zsh` | FZF with bat/eza previews + helpers |
| `30-aliases.zsh` | Modern tool aliases, git shortcuts |
| `40-ai.zsh` | Claude/Gemini/Codex wrappers, CLIProxyAPI |
| `50-tools.zsh` | Agent Browser, Bun, GHCup, Mole |
| `55-obsidian.zsh` | Obsidian vault + headless sync |
| `95-tips.zsh` | Random terminal tips on startup |
| `99-late-init.zsh` | Zoxide, cmux, local overrides |

Secrets go in `~/.config/zsh/.secret` -- sourced by `.zshrc` but excluded from this repo.
