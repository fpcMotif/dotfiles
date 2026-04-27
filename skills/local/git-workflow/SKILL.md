---
name: git-workflow
description: Git workflow automation for commits, branches, changelogs, and release management. Triggers on "commit", "branch", "changelog", "release", "merge", or git-related requests.
---

# /git-workflow — Git Workflow Skill

## Usage

```
/git-workflow commit           # Stage, craft message, commit
/git-workflow branch <name>    # Create and switch to feature branch
/git-workflow changelog        # Generate changelog from recent commits
/git-workflow pr               # Create PR with auto-generated description
/git-workflow sync             # Pull, rebase, push current branch
```

## Commit Workflow

1. Run `git status` and `git diff --stat` to assess changes.
2. Group related changes logically — don't mix unrelated work.
3. Stage specific files (avoid `git add -A` to prevent leaking secrets).
4. Craft a commit message following the repo's convention:
   - Check `git log --oneline -10` for existing style.
   - Default to conventional commits: `type(scope): description`
   - Types: feat, fix, refactor, test, docs, chore, perf, ci
5. Never skip hooks (`--no-verify`) unless explicitly asked.
6. Never amend published commits without explicit permission.

## Branch Management

- Feature branches: `feat/<short-description>`
- Bug fixes: `fix/<issue-or-description>`
- Always branch from latest main/master.
- Delete merged branches locally after PR merge.

## Changelog Generation

1. Parse commits since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
2. Group by type (Features, Fixes, Refactors, etc.).
3. Include PR/issue references where available.
4. Output as markdown suitable for CHANGELOG.md.

## PR Creation

1. Push branch with `-u` flag.
2. Use `gh pr create` with:
   - Title: concise, under 70 chars
   - Body: summary bullets + test plan
3. Return the PR URL.

## Safety Rules

- Never force-push to main/master.
- Never run `git reset --hard` without confirmation.
- Never delete remote branches without confirmation.
- Investigate merge conflicts rather than discarding changes.
- Check for uncommitted work before destructive operations.

## Tool Preference

- Use `lazygit` (via /lazygit skill) for interactive git when available.
- Fall back to raw git commands for scripted/automated workflows.
- Use `rg` to check for secrets before committing (.env, tokens, keys).
