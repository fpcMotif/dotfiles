# f's Dotfiles

My personal macOS development environment managed with [chezmoi](https://chezmoi.io/). Modular Zsh, modern Rust CLI tools, AI-first workflow, and Claude Code configuration.

## Quick Setup

```bash
# Bootstrap a fresh machine (one-liner)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply fpcMotif

# Or if chezmoi is already installed
chezmoi init --apply fpcMotif
```

After applying, create your secrets file:
```bash
cp ~/.config/zsh/.secret.example ~/.config/zsh/.secret
# Edit with your API keys
```

## Architecture

```
.
├── symlink_dot_zshrc              # ~/.zshrc -> ~/.config/zsh/.zshrc
├── symlink_dot_zshenv             # ~/.zshenv -> ~/.config/zsh/.zshenv
├── dot_zprofile                   # ~/.zprofile (PATH setup)
├── dot_config/
│   ├── zsh/
│   │   ├── dot_zshrc              # Entry point: secrets -> core rc.d/ -> host/local overlays
│   │   ├── dot_zshenv             # Universal env vars
│   │   ├── dot_secret.example     # Template for API keys
│   │   └── rc.d/                  # Modular numbered configs (00-99)
│   ├── sheldon/plugins.toml       # Sheldon (Rust) plugin manager
│   ├── starship.toml              # Starship prompt (Nerd Font glyphs)
│   └── ghostty/config             # Ghostty terminal
├── dot_claude/
│   ├── claude.md                  # Global Claude Code guidelines
│   ├── RTK.md                     # RTK (Rust Token Killer) reference
│   └── settings.json              # Plugins, hooks, permissions
├── .chezmoiignore                 # Excludes secrets from apply
└── CLAUDE.md                      # Claude Code guidance for this repo
```

## Key Patterns

- **chezmoi-managed**: `chezmoi apply` to sync, `chezmoi update` to pull + apply
- **Modular rc.d/ loading**: Numbered files (00-99) via glob, gaps for extensibility
- **Secrets isolation**: API keys in `~/.config/zsh/.secret` (chezmoi-ignored)
- **Rust CLI everywhere**: eza, bat, fd, rg, dust, procs, btm, zoxide, lazygit
- **AI-first workflow**: Claude Code with 19 plugins, tiered search policy
- **Nuanced search**: codedb (structural) / fff (frecency) / mgrep (semantic) / ast-grep (AST) / built-in Grep/Glob (regex/pattern)

## Tech Stack

| Layer | Tool |
|-------|------|
| Dotfiles | [chezmoi](https://chezmoi.io/) |
| Shell | Zsh (modular rc.d/) |
| Plugins | [Sheldon](https://github.com/rossmacarthur/sheldon) (Rust) |
| Prompt | [Starship](https://starship.rs/) (Nerd Font) |
| Terminal | [Ghostty](https://ghostty.org/) (auto light/dark) |
| AI | Claude Code, Gemini CLI, OpenCode, Codex, Amp, Droid |
| Search | codedb, fff, mgrep, ast-grep, ripgrep |
| Git | lazygit, gh, git-delta |

## Common Commands

```bash
chezmoi apply        # Apply dotfiles to $HOME
chezmoi update       # Pull latest & apply
chezmoi diff         # Preview changes
chezmoi edit ~/.zshrc  # Edit managed file
chezmoi add ~/.some-config  # Track a new file
```


## Host/Local Override Pattern

Core modules in `~/.config/zsh/rc.d/*.zsh` are intended to stay generic and deterministic in-repo.
Machine-specific behavior is layered via **optional, untracked overlays** loaded at the end of startup:

- `~/.config/zsh/rc.d/90-host.zsh` (per-machine, shared by that host)
- `~/.config/zsh/rc.d/91-local.zsh` (personal scratch/local tweaks)

Both paths are ignored by default in this repo (`.gitignore` + `.chezmoiignore`).

### Example: macOS laptop (`90-host.zsh`)

```zsh
# OrbStack integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Obsidian CLI path
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"

# Canary + agent-browser debug helpers
export AGENT_BROWSER_CDP_URL="http://localhost:9222"
alias canary-start='~/.local/bin/canary-debug'
ab() {
  if ! curl -s "http://localhost:9222/json/version" > /dev/null 2>&1; then
    ~/.local/bin/canary-debug > /dev/null 2>&1
  fi
  agent-browser "$@"
}
```

### Example: Nix-managed workstation (`90-host.zsh`)

```zsh
# Prefer Nix profiles and avoid host-specific app PATH injections
[[ -d /nix/var/nix/profiles/default/bin ]] && export PATH="/nix/var/nix/profiles/default/bin:$PATH"
[[ -d "$HOME/.nix-profile/bin" ]] && export PATH="$HOME/.nix-profile/bin:$PATH"

# Keep machine-local secrets or experiments in 91-local.zsh
```

Tip: Keep `00-89` and shared `9x` modules portable; use `90/91` only for non-portable host logic.

## Credits

Heavily inspired by and learned from:

- **[FradSer/dotfiles](https://github.com/FradSer/dotfiles)** -- Modular rc.d/ architecture, evalcache pattern, Claude provider switching, chezmoi structure, shell tips, FZF config, Ghostty setup.
- **[FradSer/dotclaude](https://github.com/FradSer/dotclaude)** -- Claude Code plugin ecosystem: git, gitflow, github, superpowers (Superpower Loop, BDD workflow), refactor, code-context (5-method retrieval), meeseeks-vetted (work verification), plugin marketplace architecture.

## License

MIT
