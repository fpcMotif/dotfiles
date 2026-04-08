# 95-tips.zsh — Random terminal tips on shell startup (inspired by FradSer)

_show_terminal_tip() {
  [[ $- != *i* ]] && return

  local -a tips

  # Core tips (always available)
  tips+=(
    "[zsh] Press %F{yellow}CTRL-R%f to fuzzy-search history -- much faster than tapping the up arrow."
    "[zsh] Type a command prefix (e.g. %F{green}ssh%f) then press %F{yellow}up%f to navigate only matching history."
    "[zsh] After editing config, run %F{green}reload%f to apply all changes immediately."
    "[zsh] %F{green}AUTO_CD%f is enabled: type a directory name to cd into it without typing cd."
    "[zsh] %F{green}CDPATH%f is set: jump to ~/Developer, ~/Downloads, ~/Documents dirs by name."
  )

  if (( $+commands[fzf] )); then
    tips+=(
      "[fzf] Press %F{yellow}CTRL-T%f to search files and paste the path to the command line."
      "[fzf] Press %F{yellow}ALT-C%f to fuzzy-search subdirectories and cd into one instantly."
      "[fzf] Run %F{green}fkill%f to interactively find and kill a process by name."
      "[fzf] Run %F{green}fif <keyword>%f to search file contents interactively across the current directory."
    )
  fi

  if (( $+commands[fd] )); then
    tips+=("[fd] fd is much faster than find and ignores .git and .gitignore entries by default.")
  fi

  if (( $+commands[rg] )); then
    tips+=("[rg] ripgrep is blazing fast. Use %F{green}rg -t py 'pattern'%f to search only Python files.")
  fi

  if (( $+commands[eza] )); then
    tips+=(
      "[eza] Your %F{green}ls/ll%f aliases use eza -- with icons, git status, and directories first."
      "[eza] Run %F{green}tree%f for a modern directory tree with icons and colors."
    )
  fi

  if (( $+commands[bat] )); then
    tips+=("[bat] Your %F{green}cat%f is aliased to bat -- syntax highlighting, line numbers, and git change markers included.")
  fi

  if (( $+commands[lazygit] )); then
    tips+=("[lazygit] Run %F{green}lg%f for a powerful git TUI. Press %F{yellow}c%f for AI commit messages.")
  fi

  if (( $+commands[zoxide] )); then
    tips+=("[zoxide] Use %F{green}z <partial-name>%f to jump to frequently visited directories.")
  fi

  if (( $+commands[claude] )); then
    tips+=(
      "[AI] Claude has %F{cyan}agent-teams%f experimental feature enabled -- great for complex multi-step tasks."
      "[AI] Run %F{green}cc%f for Claude with skip-permissions, %F{green}cofficial%f for clean env."
    )
  fi

  if (( $+commands[mgrep] )); then
    tips+=(
      "[mgrep] Run %F{green}mg 'query'%f for semantic code search, %F{green}mgw%f for web search."
      "[mgrep] Use %F{green}webai 'topic'%f for web search + AI summary."
    )
  fi

  if (( $+commands[ast-grep] )); then
    tips+=("[ast-grep] Use %F{green}sg%f for structural code search using AST patterns -- more precise than regex.")
  fi

  if (( $+commands[git] )); then
    tips+=(
      "[Git] Use %F{green}fgb%f for interactive branch switching with a live commit preview."
      "[Git] Run %F{green}fgl%f for an interactive git log -- select a commit to view its diff."
      "[Git] Use %F{green}gpf%f (push --force-with-lease) for a safer force push."
    )
  fi

  if (( $+commands[gh] )); then
    tips+=(
      "[gh] Use %F{green}gh pr list%f to view open PRs, or %F{green}gh issue status%f to check your issues."
      "[gh] Run %F{green}gh repo view --web%f to open the current GitHub repo in your browser."
    )
  fi

  if (( $+commands[pnpm] )); then
    tips+=("[pnpm] Your %F{green}p%f alias points to pnpm -- blazing fast and disk-efficient.")
  fi

  local index=$(( RANDOM % ${#tips[@]} + 1 ))
  print -P "\n%F{cyan}${tips[$index]}%f"
}

_show_terminal_tip
