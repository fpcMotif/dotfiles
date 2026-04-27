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

### macOS with Nix

This setup now supports three macOS toolchain modes so you can migrate gradually:

- **Nix-first**: prefer Nix-provided toolchains and package binaries, with Homebrew as fallback.
- **Brew-first**: keep Homebrew/ZeroBrew first while selectively adopting Nix tools.
- **Mixed**: keep both available and manually bias ordering for specific workflows.

Add mode and toggle overrides in `~/.config/zsh/.secret` (recommended for per-machine config) or `~/.zshrc.local` (highest-priority local override loaded last).

Example:

```bash
# ~/.config/zsh/.secret
export PREFERRED_TOOLCHAIN="nix"   # nix | brew | mixed
export USE_NIX_PATHS=1             # 1 to prepend nix profile paths, 0 to skip
export USE_HOMEBREW_PATHS=1        # 1 to keep Homebrew/ZeroBrew paths enabled
export USE_ZEROBREW_PATHS=0        # set 0 if fully migrating off ZeroBrew
```

Local emergency override:

```bash
# ~/.zshrc.local
export PREFERRED_TOOLCHAIN="brew"
export USE_NIX_PATHS=0
```

## Architecture

```
.
├── symlink_dot_zshrc              # ~/.zshrc -> ~/.config/zsh/.zshrc
├── symlink_dot_zshenv             # ~/.zshenv -> ~/.config/zsh/.zshenv
├── dot_zprofile                   # ~/.zprofile (PATH setup)
├── dot_config/
│   ├── zsh/
│   │   ├── dot_zshrc              # Entry point: secrets -> rc.d/ -> overrides
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

Shell load and override order (highest impact last):

1. `~/.config/zsh/.zshenv` baseline environment and early PATH helpers
2. `~/.config/zsh/.secret` machine-local secrets + toolchain toggles
3. `~/.config/zsh/rc.d/*.zsh` numbered modules (`10-env.zsh`, etc.)
4. `~/.zshrc.local` final local override layer

Recommended placement:

- Put stable machine defaults in `~/.config/zsh/.secret`
- Put temporary experiments or debugging overrides in `~/.zshrc.local`

## Key Patterns

- **chezmoi-managed**: `chezmoi apply` to sync, `chezmoi update` to pull + apply
- **Modular rc.d/ loading**: Numbered files (00-99) via glob, gaps for extensibility
- **Secrets isolation**: API keys in `~/.config/zsh/.secret` (chezmoi-ignored)
- **Toolchain mode toggles**: `PREFERRED_TOOLCHAIN`, `USE_NIX_PATHS`, `USE_HOMEBREW_PATHS`, `USE_ZEROBREW_PATHS`
- **Explicit precedence by mode**:
  - `PREFERRED_TOOLCHAIN=nix`: Nix profile paths first, then Homebrew/ZeroBrew, then system
  - `PREFERRED_TOOLCHAIN=brew`: Homebrew/ZeroBrew first, then Nix, then system
  - `PREFERRED_TOOLCHAIN=mixed`: conservative ordering; use explicit exports for one-off pinning
- **Per-machine override points**: `~/.config/zsh/.secret` for defaults, `~/.zshrc.local` for last-mile overrides
- **Rust CLI everywhere**: eza, bat, fd, rg, dust, procs, btm, zoxide, lazygit
- **AI-first workflow**: Claude Code with 19 plugins, tiered search policy
- **Nuanced search**: codedb (structural) / fff (frecency) / mgrep (semantic) / ast-grep (AST) / built-in Grep/Glob (regex/pattern)

### Migration notes: ZeroBrew/Homebrew -> Nix

1. **Start in mixed mode**:
   - Set `PREFERRED_TOOLCHAIN=mixed`
   - Keep `USE_HOMEBREW_PATHS=1` and `USE_NIX_PATHS=1`
2. **Move critical toolchains first**:
   - Install compiler/linker stack (clang, pkg-config, openssl, zlib, etc.) in Nix
   - Verify with `command -v`, `which -a`, and `type -a`
3. **Flip to Nix-first after parity**:
   - Set `PREFERRED_TOOLCHAIN=nix`
   - Keep brew enabled temporarily as fallback
4. **Retire ZeroBrew last**:
   - Set `USE_ZEROBREW_PATHS=0` only after no active projects depend on `/opt/zerobrew`
5. **Keep local rollback path**:
   - Store a quick rollback block in `~/.zshrc.local` to restore brew-first ordering if needed

### Troubleshooting checklist

If you hit `command not found` or wrong compiler/linker resolution:

- Run `echo $PATH | tr ':' '\n'` and confirm expected order for your selected mode.
- Run `type -a <cmd>` and `which -a <cmd>` to detect shadowed binaries.
- Confirm toggle values: `echo $PREFERRED_TOOLCHAIN $USE_NIX_PATHS $USE_HOMEBREW_PATHS $USE_ZEROBREW_PATHS`.
- Check override files are being sourced:
  - `~/.config/zsh/.secret`
  - `~/.zshrc.local`
- For build issues, inspect active flags:
  - `echo $CPPFLAGS`
  - `echo $LDFLAGS`
  - `echo $PKG_CONFIG_PATH`
- Restart shell (`exec zsh -l`) after toggle changes to clear stale state.

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

## Credits

Heavily inspired by and learned from:

- **[FradSer/dotfiles](https://github.com/FradSer/dotfiles)** -- Modular rc.d/ architecture, evalcache pattern, Claude provider switching, chezmoi structure, shell tips, FZF config, Ghostty setup.
- **[FradSer/dotclaude](https://github.com/FradSer/dotclaude)** -- Claude Code plugin ecosystem: git, gitflow, github, superpowers (Superpower Loop, BDD workflow), refactor, code-context (5-method retrieval), meeseeks-vetted (work verification), plugin marketplace architecture.

## License

MIT
