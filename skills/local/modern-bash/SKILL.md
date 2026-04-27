---
name: modern-bash
description: Use when writing, reviewing, or hardening Bash scripts with strict mode, safe quoting, robust traps, portable file handling, and clear diagnostics.
---

# Modern Bash

Use this skill for production-grade shell scripts and dotfile automation.

## Defaults

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

## Checklist

- Quote expansions unless intentional word splitting is required.
- Use arrays for argument lists.
- Prefer `mktemp` for temporary files/directories and clean them with `trap`.
- Check required commands with `command -v` and fail with actionable messages.
- Avoid parsing human-oriented output when machine-readable flags exist.
- Use `case` for command dispatch and validation.
- Keep macOS/BSD vs GNU differences in mind (`sed -i`, `readlink`, `date`, `stat`).

## Safety

- Never use `rm -rf "$var"` without validating `$var` is non-empty and expected.
- Avoid `eval`; if unavoidable, explain why.
- Prefer dry-run support for destructive operations.
