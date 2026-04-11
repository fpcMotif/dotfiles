# Pi Power Stack

## Retrieval Priority (follow in order)
1. **Kanban first** — `/kanban board` at session start. Claim a `ready` task before coding.
2. **Semantic code search** — `mgrep` first, `rg` to narrow.
3. **Public repo docs** — DeepWiki MCP.
4. **Open web** — `parallel_search` / `parallel_extract` / `parallel_research`.
5. **Visual checks** — `agent-browser` for screenshots, login flows, visual QA.
6. **Delegation** — `pi-subagents` for scout → planner → worker → reviewer.
7. **Design** — `emil-design-eng` and Design Deck for UI direction.

## Kanban Workflow
- `/kanban board` at session start
- `/kanban claim <id>` to move `ready -> doing` and record session ownership
- `/kanban move <id> <status>` for explicit transitions
- `/todo add <title> [--priority N] [--tag TAG] [--lane LANE] [--due YYYY-MM-DD]` for discovered work
- `/todo list [<status>|lane:<lane>|tag:<tag>]` to inspect the queue
- `/todo show <id>` before editing a task body by hand
- `/todo block <id> --reason "..."` when progress is blocked
- `/todo unblock <id> [--to <status>]` when the blocker clears; migrated blocked tasks require `--to` on first unblock
- `/todo done <id>` when finished
- Board data lives in `<project>/.pi/todos`; do not treat `~/.pi` as the task store for this pass
- WIP defaults: max 3 `doing`, max 2 `review`

## Default workflow

1. **Understand code semantically first**
   - Use `mgrep` when the user asks how something works, where logic lives, or which files matter.
   - Use `rg` only after `mgrep` narrows the area.

2. **Use the right research lane**
   - For public repo or library docs, prefer DeepWiki MCP first.
   - For open-web or current info, prefer `parallel_search`, `parallel_extract`, or `parallel_research` when authenticated.
   - If parallel tools are unavailable or unauthenticated, say so plainly and fall back.

3. **Use browsers for reality checks**
   - Use `agent-browser` for login flows, screenshots, visual QA, repro steps, and interaction testing.
   - Re-snapshot after every meaningful DOM change.

4. **Split big work into roles**
   - Use `pi-subagents` for scout → planner → worker → reviewer style tasks.
   - Keep the main thread focused on strategy, synthesis, and decision making.

5. **Design before polishing**
   - For UI direction work, load `emil-design-eng`.
   - When comparing multiple product or component directions, use Design Deck.

## Product taste rules

### Frontend
- Prefer crisp, keyboard-friendly, low-latency interactions.
- Animate only when it improves clarity.
- Favor `transform` and `opacity` over layout-changing properties.

### TUI
- Bias toward dense information, visible state, strong shortcuts, and minimal latency.
- Avoid ornamental motion. Terminal workflows should feel immediate.

### Swift / macOS
- Prefer native patterns, accessibility, reduced motion support, and clean menu or toolbar integration.
- Match platform expectations before adding custom chrome.

## Tool preferences

- **Code search:** `mgrep` → `rg`
- **Public docs:** DeepWiki MCP
- **Web research:** parallel.ai tools
- **Visual testing:** agent-browser
- **Design optioning:** Design Deck and `emil-design-eng`
- **Large tasks:** pi-subagents
- **Task tracking:** `/kanban board`, `/todo list`

## Output style

- Be concise.
- Prefer simple, testable implementations.
- Call out blockers early, especially auth and config blockers.