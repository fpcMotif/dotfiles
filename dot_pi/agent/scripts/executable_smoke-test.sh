#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin:/opt/zerobrew/prefix/bin:$PATH"

SETTINGS_FILE="$HOME/.pi/agent/settings.json"
AGENTS_FILE="$HOME/.pi/agent/AGENTS.md"
README_FILE="$HOME/.pi/agent/README.md"
SETUP_FILE="$HOME/.pi/agent/setup.sh"
MCP_FILE="$HOME/.pi/agent/mcp.json"
JUSTFILE="$HOME/.pi/agent/justfile"
KANBAN_DIR="$HOME/.pi/agent/extensions/kanban"
KANBAN_ENTRY="$KANBAN_DIR/index.ts"
LEGACY_KANBAN_EXT="$HOME/.pi/agent/extensions/kanban.ts"

VIM_INPUT_DIR="$HOME/.pi/agent/extensions/vim-input"
VIM_INPUT_ENTRY="$VIM_INPUT_DIR/index.ts"
VIM_INPUT_CHECK="$HOME/.pi/agent/scripts/vim-input-check.sh"

pass_count=0
warn_count=0
fail_count=0

pass() {
  printf 'PASS  %s\n' "$1"
  pass_count=$((pass_count + 1))
}

warn() {
  printf 'WARN  %s\n' "$1"
  warn_count=$((warn_count + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  fail_count=$((fail_count + 1))
}

have() {
  command -v "$1" >/dev/null 2>&1
}

version_of() {
  "$@" 2>/dev/null | /usr/bin/head -n 1
}

ingest_lines() {
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "$line"
    case "$line" in
      PASS\ *) pass_count=$((pass_count + 1)) ;;
      WARN\ *) warn_count=$((warn_count + 1)) ;;
      FAIL\ *) fail_count=$((fail_count + 1)) ;;
    esac
  done
}

printf '== Pi power stack smoke test ==\n\n'

for file in "$SETTINGS_FILE" "$AGENTS_FILE" "$README_FILE" "$SETUP_FILE" "$MCP_FILE" "$JUSTFILE"; do
  if [ -f "$file" ]; then
    pass "Found $(basename "$file")"
  else
    fail "Missing $file"
  fi
done

printf '\n== Kanban extension ==\n'
if [ -d "$KANBAN_DIR" ]; then
  pass 'Found kanban extension directory'
else
  fail 'Missing kanban extension directory'
fi

required_modules='index.ts types.ts schema.ts store.ts migrate.ts commands.ts tool.ts render.ts hooks.ts'
missing_modules=''
for module in $required_modules; do
  if [ -f "$KANBAN_DIR/$module" ]; then
    :
  else
    missing_modules="$missing_modules $module"
  fi
done
if [ -z "$missing_modules" ]; then
  pass 'Kanban extension module set is complete'
else
  fail "Missing kanban module(s):$missing_modules"
fi

if [ -f "$KANBAN_ENTRY" ]; then
  if grep -q 'ExtensionAPI' "$KANBAN_ENTRY"; then
    pass 'kanban/index.ts imports ExtensionAPI'
  else
    fail 'kanban/index.ts missing ExtensionAPI import'
  fi
else
  fail 'Missing kanban/index.ts entrypoint'
fi

if [ -f "$LEGACY_KANBAN_EXT" ]; then
  fail 'Legacy extensions/kanban.ts still exists; remove it for full cutover'
else
  pass 'Legacy kanban.ts entrypoint removed'
fi

printf '\n== Vim input extension ==\n'
if [ -d "$VIM_INPUT_DIR" ]; then
  pass 'Found vim-input extension directory'
else
  fail 'Missing vim-input extension directory'
fi

if [ -f "$VIM_INPUT_ENTRY" ]; then
  pass 'Found vim-input/index.ts'
else
  fail 'Missing vim-input/index.ts entrypoint'
fi

if [ -x "$VIM_INPUT_CHECK" ]; then
  pass 'vim-input-check.sh is executable'
else
  fail 'vim-input-check.sh missing or not executable'
fi


printf '\n== Skills symlinks ==\n'
expected_skills='oracle stitch-mcp ast-grep gh-fix-ci gh-address-comments github-mcp modern-bash figma doc crush linear manim-skill mgrep lazygit agent-browser'
skills_dir="$HOME/.pi/agent/skills"
linked=0
missing_skills=''
for skill in $expected_skills; do
  if [ -L "$skills_dir/$skill" ] || [ -d "$skills_dir/$skill" ]; then
    linked=$((linked + 1))
  else
    missing_skills="$missing_skills $skill"
  fi
done
if [ -z "$missing_skills" ]; then
  pass "All $linked expected skills linked"
else
  warn "Missing skills:$missing_skills ($linked linked)"
fi

printf '\n== CLI versions ==\n'
if have pi; then
  pass "pi: $(pi --version)"
else
  fail 'pi not found on PATH'
fi

if have mgrep; then
  pass "mgrep: $(version_of mgrep --version)"
else
  fail 'mgrep not found on PATH'
fi

if have agent-browser; then
  pass "agent-browser: $(agent-browser --version)"
else
  fail 'agent-browser not found on PATH'
fi

if have parallel-cli; then
  pass "parallel-cli: $(parallel-cli --version)"
  parallel_auth_json="$(parallel-cli auth --json 2>/dev/null || true)"
  if printf '%s' "$parallel_auth_json" | /usr/bin/python3 - <<'PY'
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit(1)
obj = json.loads(raw)
raise SystemExit(0 if obj.get('authenticated') else 1)
PY
  then
    pass 'parallel-cli is authenticated'
  else
    warn 'parallel-cli is installed but not authenticated; run: parallel-cli login'
  fi
else
  warn 'parallel-cli not found; install with: bun add -g parallel-web-cli'
fi

if have gh; then
  if gh auth status >/dev/null 2>&1; then
    pass 'gh is authenticated'
  else
    warn 'gh is installed but not authenticated'
  fi
else
  warn 'gh not found on PATH'
fi

printf '\n== Config checks ==\n'
config_output="$(mktemp)"
/usr/bin/python3 - <<'PY' > "$config_output"
import json, pathlib

home = pathlib.Path.home() / '.pi' / 'agent'
settings = home / 'settings.json'
mcp = home / 'mcp.json'
setup = home / 'setup.sh'
readme = home / 'README.md'
agents = home / 'AGENTS.md'
justfile = home / 'justfile'
required_packages = {
    'https://github.com/emilkowalski/skill',
    'npm:pi-design-deck',
    'npm:pi-subagents',
    'npm:pi-mcp-adapter',
    'npm:glimpseui',
    'git:github.com/HazAT/pi-parallel',
}
try:
    settings_data = json.loads(settings.read_text())
    packages = set(settings_data.get('packages', []))
    missing = sorted(required_packages - packages)
    if missing:
        print('FAIL  Missing packages in settings.json: ' + ', '.join(missing))
    else:
        print('PASS  settings.json contains the expected package set')
    prefix = settings_data.get('shellCommandPrefix', '')
    if '/usr/bin:/bin:/usr/sbin:/sbin' in prefix:
        if '$(npm config get prefix)' in prefix:
            print('FAIL  shellCommandPrefix still contains npm reference')
        else:
            print('PASS  shellCommandPrefix includes system bins (no npm)')
    else:
        print('FAIL  shellCommandPrefix is missing system bins')
except Exception as exc:
    print(f'FAIL  Could not parse settings.json: {exc}')

try:
    mcp_data = json.loads(mcp.read_text())
    deepwiki = (mcp_data.get('mcpServers') or {}).get('deepwiki') or {}
    if deepwiki.get('url') == 'https://mcp.deepwiki.com/mcp':
        print('PASS  deepwiki MCP URL is configured')
    else:
        print('FAIL  deepwiki MCP URL is missing or incorrect')
    tools = deepwiki.get('directTools') or []
    expected_tools = {'read_wiki_structure', 'read_wiki_contents', 'ask_question'}
    if expected_tools.issubset(set(tools)):
        print('PASS  deepwiki direct tools are configured')
    else:
        print('WARN  deepwiki direct tools are not fully configured')
    if mcp_data.get('settings', {}).get('idleTimeout'):
        print('PASS  idleTimeout is configured')
    else:
        print('WARN  idleTimeout not set in mcp.json settings')
except Exception as exc:
    print(f'FAIL  Could not parse mcp.json: {exc}')

vim_input_text = (home / 'README.md').read_text()
if 'extensions/vim-input/' in vim_input_text and 'vim-input-check.sh' in vim_input_text:
    print('PASS  README.md documents vim-style input mode')
else:
    print('FAIL  README.md is missing vim-style input mode documentation')


setup_text = setup.read_text()
if 'bun install' in setup_text and 'bun add -g parallel-web-cli@latest' in setup_text and 'npm install' not in setup_text:
    print('PASS  setup.sh is Bun-first and avoids npm install drift')
else:
    print('FAIL  setup.sh is missing Bun-first install steps or still references npm install')

readme_text = readme.read_text()
if '/kanban claim <id>' in readme_text and '<project>/.pi/todos' in readme_text:
    print('PASS  README.md documents the project-local kanban workflow')
else:
    print('FAIL  README.md is missing project-local kanban workflow details')

agents_text = agents.read_text()
if '/kanban claim <id>' in agents_text and '/todo block <id> --reason' in agents_text:
    print('PASS  AGENTS.md matches the implemented kanban commands')
else:
    print('FAIL  AGENTS.md is missing the implemented kanban command surface')

justfile_text = justfile.read_text()
if '/kanban.ts' in justfile_text or 'kanban.ts' in justfile_text:
    print('FAIL  justfile still references kanban.ts instead of the directory extension')
else:
    print('PASS  justfile points at the kanban directory extension')
PY
ingest_lines < "$config_output"
rm -f "$config_output"

printf '\n== DeepWiki MCP handshake ==\n'
deepwiki_output="$(mktemp)"
/usr/bin/python3 - <<'PY' > "$deepwiki_output"
import json, urllib.request
url = 'https://mcp.deepwiki.com/mcp'
body = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
        'protocolVersion': '2025-03-26',
        'capabilities': {},
        'clientInfo': {'name': 'pi-smoke-test', 'version': '0.1.0'},
    },
}
try:
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = resp.read().decode('utf-8', errors='ignore')
    wanted = ['read_wiki_structure', 'read_wiki_contents', 'ask_question']
    if all(name in payload for name in wanted):
        print('PASS  DeepWiki MCP is reachable and advertises the expected public tools')
    else:
        print('WARN  DeepWiki MCP responded, but expected tool names were not all present')
except Exception as exc:
    print(f'FAIL  DeepWiki MCP handshake failed: {exc}')
PY
ingest_lines < "$deepwiki_output"
rm -f "$deepwiki_output"

printf '\n== Installed Pi packages ==\n'
if have pi; then
  pi list || true
fi

printf '\n== Summary ==\n'
printf 'PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi