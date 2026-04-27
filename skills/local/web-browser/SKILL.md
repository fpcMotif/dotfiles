---
name: web-browser
description: Browser automation via CDP for testing, scraping, visual QA, and form interactions. Triggers on "open browser", "test in browser", "screenshot", "navigate to", or web URLs.
---

# /web-browser — CDP Browser Automation Skill

## Usage

```
/web-browser <url>              # Navigate and screenshot
/web-browser test <url>         # Run visual QA checks
/web-browser fill <url>         # Fill forms on a page
/web-browser extract <url>      # Extract structured data
```

## Capabilities

### Navigation & Screenshots
- Navigate to URLs, wait for load, take screenshots.
- Use `agent-browser` skill tools when available.
- Fallback: use chrome-in-chrome MCP tools (mcp__claude-in-chrome__*).

### Visual QA
- Screenshot before and after interactions.
- Compare expected vs actual layout.
- Check responsive breakpoints (mobile, tablet, desktop).
- Verify text content, colors, element visibility.

### Form Filling
- Identify form fields by label, placeholder, or selector.
- Fill inputs, select dropdowns, check boxes.
- Submit and verify success/error states.

### Data Extraction
- Read page text and structured content.
- Extract tables, lists, and key-value pairs.
- Parse JSON-LD, Open Graph, or meta tags.

## Tool Priority

1. `agent-browser` skill (if available) — preferred for full CDP control
2. `mcp__claude-in-chrome__*` tools — for Chrome extension-based automation
3. `curl` / `wget` — for simple HTTP requests (no JS rendering)

## Rules

- Always call `tabs_context_mcp` first to check existing browser state.
- Create new tabs instead of reusing unknown ones.
- Never trigger alert/confirm/prompt dialogs — they block the extension.
- If a page requires auth, ask the user before entering credentials.
- Stop and ask after 3 consecutive failures on the same page.
