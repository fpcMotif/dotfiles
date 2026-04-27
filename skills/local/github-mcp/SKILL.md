---
name: github-mcp
description: Use for GitHub MCP setup and GitHub repository operations involving issues, pull requests, Actions, releases, code search, or MCP server troubleshooting.
---

# GitHub MCP

Use this skill when the task involves GitHub MCP server setup or GitHub operations through MCP/CLI tooling.

## Workflow

1. Verify authentication before making API calls:
   - `gh auth status`
   - For MCP, confirm the configured server has an appropriate token and scopes.
2. Prefer `gh` for scripted operations when available; use MCP tools when the user specifically asks for MCP or the MCP server exposes needed context.
3. For PR/issue work, gather context before editing:
   - `gh pr view`, `gh pr diff`, `gh pr checks`
   - `gh issue view` / `gh issue list`
4. Summarize the planned mutation before creating issues, commenting, changing labels, closing PRs, or rerunning workflows.

## Safety

- Never print tokens or secrets.
- Do not force-push, close issues/PRs, delete branches, or change repository settings without explicit confirmation.
- If auth is missing, tell the user exactly which login command to run.
