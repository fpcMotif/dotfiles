---
name: lazygit
description: Full lazygit integration for git workflows. Use for commit creation, branch management, stash operations, rebase, merge, push/pull, diff review, and all git operations through lazygit's TUI.
---

# Lazygit Integration

## Quick start

```bash
lg                      # Launch lazygit (alias)
# Within lazygit:
#   ? - show all keybindings
#   e - edit config
#   q - quit
#   c - commit
#   C - commit amend
#   P - push
#   p - pull
#   r - rebase
#   M - merge
#   s - stash
#   Space - stage/unstage
#   Enter - inspect
```

## Core Workflows

### 1. Commit Workflow
```bash
# Stage files, write commit message, commit
lg  # then press: files navigation -> Space (stage) -> c (commit)

# Amend last commit
lg  # then press: c (commit) -> C (amend)

# Fixup commit
lg  # then press: select commit -> R (fixup)
```

### 2. Branch Workflow
```bash
# Create new branch
lg  # then press: b (branch) -> c (create)

# Switch branch
lg  # then press: b (branch) -> enter branch -> Space (checkout)

# Delete branch
lg  # then press: b (branch) -> select branch -> d (delete)
```

### 3. Rebase Workflow
```bash
# Interactive rebase on current branch
lg  # then press: r (rebase) -> i (interactive)

# Rebase onto another branch
lg  # then press: r (rebase) -> select target branch

# Continue rebase after resolving conflicts
lg  # then press: r (rebase) -> continue
```

### 4. Merge & Conflict Resolution
```bash
# Merge branch
lg  # then press: M (merge) -> select branch

# Resolve conflicts
lg  # then press: files -> Enter (resolve) -> choices:
#   - Use my version
#   - Use their version
#   - Use both
#   - Edit manually
```

### 5. Stash Workflow
```bash
# Quick stash
lg  # then press: s (stash) -> s (stash)

# Stash with message
lg  # then press: s (stash) -> enter message -> c (create)

# Apply stash
lg  # then press: s (stash) -> select -> a (apply)

# Drop stash
lg  # then press: s (stash) -> select -> d (drop)
```

### 6. Push/Pull Workflow
```bash
# Push
lg  # then press: P (push)

# Pull with rebase
lg  # then press: p (pull) -> r (rebase)

# Push to specific remote
lg  # then press: P (push) -> select remote
```

## Diff & Review

### View Diff
```bash
# Working tree diff
lg  # then press: d (diff) -> w (working copy)

# Staged diff
lg  # then press: d (diff) -> s (staged)

# Commit diff
lg  # then press: select commit -> d (diff)
```

### File History
```bash
lg  # then press: files -> select file -> h (history)
```

### Blame
```bash
lg  # then press: files -> select file -> B (blame)
```

## Undo/Redo

```bash
# Undo last action
lg  # then press: z (undo) or Ctrl+z

# Redo
lg  # then press: Ctrl+r or Z (redo)
```

## Search & Filter

### Search commits
```bash
lg  # then press: / (search) -> type query
```

### Filter by author
```bash
lg  # then press: f (filter) -> a (author) -> type name
```

### Filter by path
```bash
lg  # then press: f (filter) -> p (path) -> select file
```

## Submodules

```bash
# Update submodule
lg  # then press: S (submodule) -> u (update)

# Init submodule
lg  # then press: S (submodule) -> i (init)
```

## Tags

```bash
# Create tag
lg  # then press: t (tags) -> c (create)

# Delete tag
lg  # then press: t (tags) -> select -> d (delete)
```

## Worktrees

```bash
# Create worktree
lg  # then press: W (worktree) -> c (create)

# Delete worktree
lg  # then press: W (worktree) -> select -> d (delete)
```

---

## Advanced Operations

### Cherry-pick Workflow
```bash
# Copy commits between branches
lg  # commits panel -> select commit -> C (copy)
    # switch to target branch
    # press v (paste/cherry-pick)
    # press G to clear cherry-pick selection

# Cherry-pick single commit
lg  # commits panel -> select commit -> c (cherry-pick directly)
```

### Bisect Workflow
```bash
# Binary search for bug introduction
lg  # commits panel -> select bad commit -> b (bisect start)
    # lazygit guides through:
    #   g - mark as good
    #   b - mark as bad
    #   s - skip commit
    #   r - reset bisect
```

### Reflog Navigation
```bash
# Recover lost commits/branches
lg  # commits panel -> R (reflog) or g (reflog)
    # navigate history of all HEAD movements
    # checkout or create branch from any entry
```

### Advanced Rebase Operations
```bash
# Edit commit in middle of history
lg  # commits -> select commit -> e (edit) -> make changes -> continue

# Reorder commits
lg  # commits -> select commit -> ctrl+j (move down) / ctrl+k (move up)

# Split commit
lg  # commits -> select commit -> e (edit) -> reset HEAD~1 -> stage parts -> commit multiple

# Squash all fixup commits
lg  # commits panel -> S (squash all above fixup commits)
```

### Patch Management
```bash
# Create patch from commit
lg  # commits -> select -> ctrl+o (create patch)

# Apply patch
lg  # files panel -> ctrl+p (apply patch)
```

---

## mgrep + Lazygit Integration

### Pre-commit Semantic Search
```bash
# Before committing, understand context
mgrep "functions that call this API endpoint"
mgrep "How is {function_name} used in tests?"

# Analyze staged changes
git diff --staged | mgrep --answer "Summarize these changes"
```

### Conflict Resolution Context
```bash
# When resolving conflicts, get semantic context
mgrep "What is the purpose of {conflicting_function}?" .
mgrep "How was {feature} implemented before?" .
```

### Custom Command Keys (in lazygit)
- `m` - mgrep semantic search in repo
- `M` - mgrep search in selected file
- `c` - AI-generated commit message
- `r` - AI code review of diff

---

## Custom Commands (from ~/.config/lazygit/config.yml)

The user has these custom commands configured:

| Key | Action |
|-----|--------|
| `c` | Generate commit message with OMO |
| `m` | mgrep RAG search in repo |
| `M` | mgrep search in selected file |
| `r` | Review code diff with OMO |
| `s` | Explain git status |
| `b` | AI branch naming |
| `o` | Open OMO terminal |
| `w` | Start mgrep watch |

## Integration with Sisyphus

### Generate Commit Message
```bash
# In lazygit, when on commit message screen:
# Press 'c' to invoke OMO for commit message generation
```

### Code Review with OMO
```bash
# Select a file in lazygit, press 'r'
# OMO will review the diff and suggest improvements
```

### Branch Naming
```bash
# In branches view, press 'b'
# OMO will suggest a branch name based on your input
```

## Best Practices

1. **Use undo liberally** - `z` undoes any action, even commits
2. **Stage precisely** - Stage hunks with `Space`, individual lines with `v`
3. **Review before commit** - Press `d` to see staged changes
4. **Pull with rebase** - Use `p` then `r` for clean history
5. **Squash during rebase** - Use `s` on commits to squash

## Scripted Operations (for agents)

When calling lazygit from scripts:

```bash
# Non-interactive commit
lg commit -m "message"

# Specific operations
lg push
lg pull
lg checkout branch
lg branch create name
lg stash push -m "message"

# With custom commands
lg custom-command c  # Generate commit message
lg custom-command m  # mgrep search
```

## Troubleshooting

### "Nothing to commit"
- Check `a` (untracked files) panel
- Press `a` to toggle untracked files display

### Merge conflicts
- Go to `files` panel
- Select conflicted file
- Press `Enter` to resolve

### Detached HEAD
- Press `b` (branches)
- Select branch to checkout
- Or create new branch from detached state
