---
name: review
description: Code review for commits, diffs, PRs, and branches. Triggers on /review, "review this", "check my changes", or PR URLs.
---

# /review — Code Review Skill

## Usage

```
/review                    # Review staged + unstaged changes
/review HEAD~3..HEAD       # Review last 3 commits
/review <branch>           # Review branch diff against main/master
/review <pr-url>           # Review a GitHub PR
/review <file>             # Review a specific file's recent changes
```

## Review Process

1. **Gather context**
   - Run `git diff --stat` to understand scope.
   - Run `git log --oneline` for the relevant range.
   - Read changed files fully before commenting.

2. **Check each file for**
   - Security: injection, auth bypass, secrets, OWASP top 10
   - Correctness: off-by-one, null/undefined, race conditions, error handling
   - Performance: N+1 queries, unnecessary allocations, missing indexes
   - Readability: unclear names, overly clever code, missing context
   - Tests: are changes covered? Are edge cases tested?

3. **For PRs (GitHub)**
   - Use `gh pr diff <number>` to get the full diff.
   - Use `gh pr view <number>` for description and metadata.
   - Use `gh pr checks <number>` to see CI status.
   - Cross-reference PR description with actual changes.

4. **Output format**
   - Group findings by severity: CRITICAL > WARNING > SUGGESTION > NITPICK
   - For each finding: file:line, what's wrong, why it matters, suggested fix
   - End with a summary verdict: APPROVE / REQUEST CHANGES / NEEDS DISCUSSION

## Rules

- Never approve code with known security vulnerabilities.
- Flag any committed secrets, tokens, or credentials as CRITICAL.
- If the diff is too large (>500 lines), break review into logical chunks.
- Be specific — cite exact lines, not vague descriptions.
