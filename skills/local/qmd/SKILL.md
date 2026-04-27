---
name: qmd
description: Use qmd for local Markdown search over notes, docs, and vaults; retrieve focused snippets before reading large Markdown collections.
---

# QMD — Quick Markdown Search

Use this skill when searching a local Markdown corpus such as docs, notes, or an Obsidian vault.

## Workflow

1. Check availability: `command -v qmd`.
2. Prefer focused searches over opening entire vaults:
   - lexical search for exact terms
   - semantic/vector search for concepts, if configured
3. Retrieve snippets first, then read only the most relevant files.
4. If `qmd` is not installed, fall back to `rg --glob '*.md'` and tell the user qmd is unavailable.

## Examples

```bash
qmd status
qmd search "CAP theorem consistency"
qmd search --type vec "tradeoff between consistency and availability"
```
