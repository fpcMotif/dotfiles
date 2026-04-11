#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin:/opt/zerobrew/prefix/bin:$PATH"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

require_cmd bun
require_cmd pi

printf '== Pi power stack bootstrap ==\n\n'

printf '%s\n' '-> Installing local extension dependencies'
bun install

printf '\n%s\n' '-> Updating agent-browser'
bun add -g agent-browser@latest

printf '\n%s\n' '-> Installing Pi packages'
pi install https://github.com/emilkowalski/skill
pi install npm:pi-design-deck
pi install npm:pi-subagents
pi install npm:pi-mcp-adapter
pi install npm:glimpseui
pi install git:github.com/HazAT/pi-parallel

printf '\n%s\n' '-> Priming DeepWiki MCP metadata cache'
pi -p "/mcp reconnect deepwiki" || true

printf '\n%s\n' '-> Installing parallel CLI'
bun add -g parallel-web-cli@latest

printf '\n== Next steps ==\n'
printf '%s\n' '1. Restart pi (or run /reload).'
printf '%s\n' '2. Optional: authenticate parallel.ai for live web research: parallel-cli login'
printf '%s\n' '3. Run the smoke test: ~/.pi/agent/scripts/smoke-test.sh'