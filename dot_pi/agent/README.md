# Pi Power Stack

Personal Pi setup for high-agency software work across frontend, terminal/TUI, and Swift/macOS projects.

## Quick start

```bash
cd ~/.pi/agent
./setup.sh
```

Then restart Pi or run `/reload`, and verify the environment:

```bash
~/.pi/agent/scripts/smoke-test.sh
```

Optional, only if you want live parallel.ai web research:

```bash
parallel-cli login
```

## Vim-style input mode

The local `extensions/vim-input/` extension is auto-discovered and makes the main Pi prompt behave more like Gemini CLI's vim editing mode:

- prompt starts in `INSERT` mode
- press `Esc` to enter `NORMAL` mode
- supported normal-mode commands now include `h`, `j`, `k`, `l`, `0`, `$`, `w`, `b`, `e`, `gg`, `G`, `i`, `a`, `A`, `I`, `o`, `x`, `u`, `dd`, `dw`, `de`, `d$`, `cw`, `ce`, `c$`, and `p`
- `v` enters visual mode; visual selections currently report mode/selection size in the status line and support `d`, `c`, and `y`

Verification helper:

```bash
~/.pi/agent/scripts/vim-input-check.sh
```

It checks Pi editing logic directly and runs a translated-source behavior check for the OMP extension logic.


## Installed package stack

- `https://github.com/emilkowalski/skill` — design engineering taste and motion guidance
- `npm:pi-design-deck` — visual option decks for UI decisions
- `npm:pi-subagents` — scout/planner/worker/reviewer delegation
- `npm:pi-mcp-adapter` — MCP support without ballooning context
- `npm:glimpseui` — native macOS windows for MCP and design UIs
- `git:github.com/HazAT/pi-parallel` — parallel.ai web tools

## Project-local Kanban store

This setup keeps board state inside each project instead of under `~/.pi`:

- tasks: `<project>/.pi/todos/*.md`
- config: `<project>/.pi/kanban.json`
- event log: `<project>/.pi/todos/.events.ndjson`

Task files stay human-readable: JSON front matter for structured metadata, markdown body for notes.

## Kanban command surface

- `/kanban board` — show the current board
- `/kanban claim <id>` — move a ready task into `doing` and record the claiming session
- `/kanban move <id> <status>` — explicit transition (`backlog|ready|doing|review|done|blocked`)
- `/todo add <title> [--priority N] [--tag TAG] [--lane LANE] [--due YYYY-MM-DD]`
- `/todo list [<status>|lane:<lane>|tag:<tag>]`
- `/todo show <id>`
- `/todo block <id> --reason "..."`
- `/todo unblock <id> [--to <status>]`
- `/todo done <id>`

## Suggested workflow inside a repo

1. Start with `/kanban board`.
2. Claim one ready task before coding with `/kanban claim <id>`.
3. Add discovered work explicitly with `/todo add ...` instead of keeping it in your head.
4. Use `/todo block` and `/todo unblock` when progress is blocked. For migrated blocked tasks, pass `--to <status>` the first time you unblock them.
5. Finish with `/todo done <id>`.

WIP defaults: max 3 tasks in `doing`, max 2 tasks in `review`. Override them per project via `<project>/.pi/kanban.json`.

## Key local files

- `settings.json` — defaults, package list, shell PATH fixups
- `AGENTS.md` — session workflow rules for future runs
- `mcp.json` — official DeepWiki MCP wiring
- `extensions/kanban/index.ts` — project-local task system
- `extensions/vim-input/index.ts` — vim-style prompt editing for the main input box
- `scripts/smoke-test.sh` — setup verification
- `scripts/kanban-e2e.sh` — end-to-end task-flow verification
- `scripts/vim-input-check.sh` — vim-style input verification for Pi and OMP

## Important notes

### agent-browser

Updated to the latest version available during setup.

### DeepWiki MCP

Configured against the official public endpoint:

- `https://mcp.deepwiki.com/mcp`

Direct tools configured:

- `read_wiki_structure`
- `read_wiki_contents`
- `ask_question`

If direct tools do not show up immediately, restart Pi once after the metadata cache is populated.