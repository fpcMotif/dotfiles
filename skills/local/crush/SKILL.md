---
name: crush
description: Use for Charmbracelet Crush CLI configuration, skills setup, provider/LSP/MCP configuration, and troubleshooting Crush agent behavior.
---

# Crush CLI

Use this skill when working with [Charmbracelet Crush](https://github.com/charmbracelet/crush) configuration or runtime behavior.

## Workflow

1. Inspect local configuration first:
   - `~/.config/crush/crush.json`
   - project-local `.crush/` or `crush.json` files, if present
2. For skill-related issues, check the active skills directories:
   - `$CRUSH_SKILLS_DIR`
   - `$XDG_CONFIG_HOME/agents/skills` or `~/.config/agents/skills`
   - `$XDG_CONFIG_HOME/crush/skills` or `~/.config/crush/skills`
3. Prefer minimal config changes and explain any provider, MCP, or permission implications before editing.
4. Validate with `crush --help`, `crush config`, or the closest available Crush diagnostic command.

## Rules

- Do not overwrite provider credentials.
- Ask before changing default models or network-facing MCP servers.
- Keep changes portable across macOS and Linux unless the user asks otherwise.
