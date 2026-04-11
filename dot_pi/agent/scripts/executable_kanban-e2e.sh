#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin:/opt/zerobrew/prefix/bin:$PATH"

AGENT_ROOT="$HOME/.pi/agent"
STORE_MODULE="$AGENT_ROOT/extensions/kanban/store.ts"

pass_count=0
warn_count=0
fail_count=0
scratch_dirs=()
RUN_PI_STATUS=0
RUN_PI_OUTPUT=""

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

new_project() {
  local dir
  dir="$(mktemp -d)"
  scratch_dirs+=("$dir")
  printf '%s\n' "$dir"
}

cleanup() {
  for dir in "${scratch_dirs[@]:-}"; do
    [ -n "$dir" ] || continue
    rm -rf "$dir"
  done
}
trap cleanup EXIT

run_pi() {
  local cwd="$1"
  local prompt="$2"
  local output_file
  output_file="$(mktemp)"
  set +e
  (
    cd "$cwd"
    pi -p "$prompt"
  ) >"$output_file" 2>&1
  RUN_PI_STATUS=$?
  set -e
  RUN_PI_OUTPUT="$(<"$output_file")"
  rm -f "$output_file"
}

assert_run_success_contains() {
  local needle="$1"
  local message="$2"
  if [ "$RUN_PI_STATUS" -eq 0 ] && [[ "$RUN_PI_OUTPUT" == *"$needle"* ]]; then
    pass "$message"
  else
    fail "$message"
    printf -- '---- status=%s output ----\n%s\n-------------------------\n' "$RUN_PI_STATUS" "$RUN_PI_OUTPUT"
  fi
}

assert_run_failure_contains() {
  local needle="$1"
  local message="$2"
  if [ "$RUN_PI_STATUS" -ne 0 ] && [[ "$RUN_PI_OUTPUT" == *"$needle"* ]]; then
    pass "$message"
  else
    fail "$message"
    printf -- '---- status=%s output ----\n%s\n-------------------------\n' "$RUN_PI_STATUS" "$RUN_PI_OUTPUT"
  fi
}

assert_not_exists() {
  local path="$1"
  local message="$2"
  if [ ! -e "$path" ]; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_exists() {
  local path="$1"
  local message="$2"
  if [ -e "$path" ]; then
    pass "$message"
  else
    fail "$message"
  fi
}

single_task_file() {
  local project="$1"
  TASK_DIR="$project/.pi/todos" /usr/bin/python3 - <<'PY'
import os, pathlib
root = pathlib.Path(os.environ['TASK_DIR'])
files = sorted(path for path in root.glob('*.md'))
if len(files) != 1:
    raise SystemExit(f'expected exactly one task file, found {len(files)} in {root}')
print(files[0])
PY
}

assert_task_meta() {
  local path="$1"
  local code="$2"
  local message="$3"
  if TASK_PATH="$path" /usr/bin/python3 - <<PY
import json, os, pathlib, re
path = pathlib.Path(os.environ['TASK_PATH'])
text = path.read_text()
match = re.match(r'^---\n([\s\S]*?)\n---\n?([\s\S]*)$', text)
if not match:
    raise SystemExit(f'{path}: missing JSON front matter')
meta = json.loads(match.group(1))
body = match.group(2).strip()
${code}
PY
  then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_event_log() {
  local path="$1"
  local code="$2"
  local message="$3"
  if EVENT_PATH="$path" /usr/bin/python3 - <<PY
import json, os, pathlib
path = pathlib.Path(os.environ['EVENT_PATH'])
events = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
${code}
PY
  then
    pass "$message"
  else
    fail "$message"
  fi
}

printf '== Kanban end-to-end verification ==\n\n'

printf '== Empty board read path ==\n'
empty_project="$(new_project)"
run_pi "$empty_project" "/kanban board"
assert_run_success_contains 'Board is empty. Use /todo add <title> to create a task.' 'Empty board command reports no tasks'
assert_not_exists "$empty_project/.pi/todos" 'Empty board read does not create .pi/todos storage'

printf '\n== Headless invalid usage ==\n'
run_pi "$empty_project" '/todo'
assert_run_failure_contains 'Usage: /todo add|list|show|done|block|unblock [--to <status>] ...' 'Headless /todo usage errors exit non-zero'
run_pi "$empty_project" '/kanban'
assert_run_failure_contains 'Usage: /kanban board | claim <id> | move <id> <status>' 'Headless /kanban usage errors exit non-zero'


printf '\n== CLI parser hardening ==\n'
run_pi "$empty_project" '/todo add Build widget --priority 2oops'
assert_run_failure_contains 'priority must be an integer' 'Malformed numeric priority is rejected'
run_pi "$empty_project" '/todo add Build widget -x'
assert_run_failure_contains 'Unknown flag: -x' 'Unknown short flag is rejected'
run_pi "$empty_project" '/todo add "Build widget --priority 2'
assert_run_failure_contains 'Unmatched quote in arguments' 'Unmatched quotes are rejected for /todo add'
run_pi "$empty_project" '/todo list lane:"front end'
assert_run_failure_contains 'Unmatched quote in arguments' 'Unmatched quotes are rejected for /todo list'

parser_project="$(new_project)"
run_pi "$parser_project" '/todo add Lane task --lane "front end" --tag "ui work"'
assert_run_success_contains 'Created T-001: Lane task' 'Quoted lane setup task is created'
run_pi "$parser_project" '/todo list lane:"front end"'
assert_run_success_contains 'lane:front end' 'Quoted lane filters match stored tasks'
run_pi "$parser_project" '/todo list tag:"ui work"'
assert_run_success_contains '#ui work' 'Quoted tag filters match stored tasks'


printf '\n== Main task lifecycle ==\n'
project="$(new_project)"
run_pi "$project" '/todo add Build widget --priority 2 --tag ui --lane frontend --due 2026-03-31'
assert_run_success_contains 'Created T-001: Build widget (backlog, P2)' 'Add command creates canonical task alias'
assert_exists "$project/.pi/todos/.events.ndjson" 'Add command creates append-only event log'

task_file="$(single_task_file "$project")"
assert_task_meta "$task_file" "
assert meta['alias'] == 'T-001'
assert meta['status'] == 'backlog'
assert meta['priority'] == 2
assert meta['tags'] == ['ui']
assert meta['lane'] == 'frontend'
assert meta['due_at'] == '2026-03-31'
assert meta['version'] == 1
assert body == '## Notes'
" 'Initial task file matches canonical schema'

run_pi "$project" '/todo list tag:ui'
assert_run_success_contains 'T-001 [backlog] P2 Build widget lane:frontend #ui due:2026-03-31' 'List command filters by tag and renders task line'

run_pi "$project" '/todo show T-001'
assert_run_success_contains 'status: backlog' 'Show command renders task details'

run_pi "$project" '/kanban move T-001 ready'
assert_run_success_contains 'T-001 "Build widget" backlog → ready' 'Move command transitions backlog to ready'

run_pi "$project" '/kanban claim T-001'
assert_run_success_contains 'T-001 "Build widget" ready → doing' 'Claim command moves ready task into doing'
assert_task_meta "$task_file" "
assert meta['status'] == 'doing'
assert meta['started_at']
assert meta['claimed_by_session']
assert meta['version'] == 3
" 'Claim records started_at, claimant, and version bump'

run_pi "$project" '/todo block T-001 --reason waiting-on-api'
assert_run_success_contains 'T-001 "Build widget" doing → blocked' 'Block command moves task into blocked'
assert_task_meta "$task_file" "
assert meta['status'] == 'blocked'
assert meta['blocked_reason'] == 'waiting-on-api'
assert meta['version'] == 4
" 'Block command stores blocked_reason and version bump'

run_pi "$project" '/todo unblock T-001'
assert_run_success_contains 'T-001 unblocked → doing' 'Unblock command restores prior active status'
assert_task_meta "$task_file" "
assert meta['status'] == 'doing'
assert 'blocked_reason' not in meta
assert meta['version'] == 5
" 'Unblock clears blocked_reason and preserves active work'

run_pi "$project" '/kanban move T-001 review'
assert_run_success_contains 'T-001 "Build widget" doing → review' 'Move command transitions doing to review'

run_pi "$project" '/todo done T-001'
assert_run_success_contains 'T-001 "Build widget" → done' 'Done command marks task complete'
assert_task_meta "$task_file" "
assert meta['status'] == 'done'
assert meta['finished_at']
assert 'claimed_by_session' not in meta
assert meta['version'] == 7
" 'Done command sets terminal fields and clears active claim'

assert_event_log "$project/.pi/todos/.events.ndjson" "
expected = ['created', 'moved', 'claimed', 'blocked', 'unblocked', 'moved', 'done']
assert [event['type'] for event in events] == expected
assert all(events[index]['task_version'] == index + 1 for index in range(len(events)))
" 'Event log captures the full lifecycle in append-only order'

printf '\n== WIP enforcement ==\n'
wip_project="$(new_project)"
mkdir -p "$wip_project/.pi"
cat > "$wip_project/.pi/kanban.json" <<'JSON'
{"wip":{"doing":1,"review":1}}
JSON
run_pi "$wip_project" '/todo add First task'
run_pi "$wip_project" '/kanban move T-001 ready'
run_pi "$wip_project" '/kanban claim T-001'
run_pi "$wip_project" '/todo add Second task'
run_pi "$wip_project" '/kanban move T-002 ready'
run_pi "$wip_project" '/kanban claim T-002'
assert_run_failure_contains 'WIP limit reached for doing (1/1).' 'Claim command enforces doing WIP limit'
second_task="$wip_project/.pi/todos/t-002-second-task.md"
assert_task_meta "$second_task" "
assert meta['status'] == 'ready'
assert meta['version'] == 2
" 'Blocked claim leaves the second task in ready'

printf '\n== Legacy migration ==\n'
migration_project="$(new_project)"
mkdir -p "$migration_project/.pi/todos"
cat > "$migration_project/.pi/todos/001-old-task.md" <<'TASK'
---
{"id":"001","title":"Old task","status":"blocked","priority":4,"created":"2026-03-01T00:00:00.000Z","updated":"2026-03-02T00:00:00.000Z","assignee":null,"tags":["legacy"],"blocked_by":["missing-api"]}
---
## Description
legacy body
TASK
run_pi "$migration_project" '/kanban board'
assert_run_success_contains 'Migrated legacy kanban tasks to the canonical schema.' 'Board load performs one-shot legacy migration'
assert_not_exists "$migration_project/.pi/todos/001-old-task.md" 'Legacy task filename is removed during migration'
migrated_task="$migration_project/.pi/todos/t-001-old-task.md"
assert_exists "$migrated_task" 'Legacy task is rewritten to canonical filename'
assert_task_meta "$migrated_task" "
assert meta['alias'] == 'T-001'
assert meta['status'] == 'blocked'
assert meta['blocked_reason'] == 'missing-api'
assert meta['depends_on'] == ['missing-api']
assert meta['version'] == 1
assert body == '## Description\nlegacy body'
" 'Legacy task metadata is migrated into canonical schema'
run_pi "$migration_project" '/todo unblock T-001'
assert_run_failure_contains 'Cannot infer an unblock target for migrated task T-001' 'Migrated blocked task requires an explicit unblock target'
run_pi "$migration_project" '/todo unblock T-001 --to ready'
assert_run_success_contains 'T-001 unblocked → ready' 'Migrated blocked task can be unblocked with an explicit target'
assert_event_log "$migration_project/.pi/todos/.events.ndjson" "
assert [event['type'] for event in events] == ['migrated', 'unblocked']
assert events[0]['details']['unblock_requires_target'] is True
" 'Migration records preserve explicit-unblock requirement in the event log'

migration_claim_project="$(new_project)"
mkdir -p "$migration_claim_project/.pi/todos"
cat > "$migration_claim_project/.pi/todos/001-ready-task.md" <<'TASK'
---
{"id":"001","title":"Ready task","status":"ready","priority":4,"created":"2026-03-01T00:00:00.000Z","updated":"2026-03-02T00:00:00.000Z","assignee":"legacy-session","tags":[],"blocked_by":[]}
---
## Description
legacy ready body
TASK
run_pi "$migration_claim_project" '/kanban board'
assert_task_meta "$migration_claim_project/.pi/todos/t-001-ready-task.md" "
assert meta['status'] == 'ready'
assert 'claimed_by_session' not in meta
" 'Migration keeps ready tasks unclaimed even if legacy assignee was set'


printf '\n== Lock handling ==\n'
lock_project="$(new_project)"
run_pi "$lock_project" '/todo add Locked baseline'
assert_run_success_contains 'Created T-001: Locked baseline' 'Lock test baseline task is created'
mkdir -p "$lock_project/.pi/.kanban.lock"
printf '%s\n' "{\"pid\":$$,\"token\":\"live-lock\",\"acquired_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$lock_project/.pi/.kanban.lock/owner.json"
run_pi "$lock_project" '/todo add Should fail while live lock exists'
assert_run_failure_contains 'Kanban board is busy; another session is mutating it. Retry in a moment.' 'Live lock blocks concurrent mutation attempts'
assert_not_exists "$lock_project/.pi/todos/t-002-should-fail-while-live-lock-exists.md" 'Live lock failure does not create a second task file'

stale_lock_project="$(new_project)"
mkdir -p "$stale_lock_project/.pi/.kanban.lock"
printf '%s\n' '{"pid":999999,"token":"dead-lock","acquired_at":"2026-01-01T00:00:00Z"}' > "$stale_lock_project/.pi/.kanban.lock/owner.json"
run_pi "$stale_lock_project" '/todo add Recovered stale lock'
assert_run_success_contains 'Created T-001: Recovered stale lock' 'Dead-owner lock is recovered automatically'

live_malformed_lock_project="$(new_project)"
mkdir -p "$live_malformed_lock_project/.pi/.kanban.lock"
lock_path="$live_malformed_lock_project/.pi/.kanban.lock"
(
  while true; do
    printf '%s\n' 'not-json' > "$lock_path/owner.json"
    LOCK_PATH="$lock_path" /usr/bin/python3 - <<'PY'
import os, pathlib
path = pathlib.Path(os.environ['LOCK_PATH'])
os.utime(path, None)
PY
    /bin/sleep 0.1
  done
) &
refresher_pid=$!
run_pi "$live_malformed_lock_project" '/todo add Fresh malformed lock should wait'
kill "$refresher_pid" >/dev/null 2>&1 || true
wait "$refresher_pid" >/dev/null 2>&1 || true
assert_run_failure_contains 'Kanban board is busy; another session is mutating it. Retry in a moment.' 'Actively refreshed malformed lock is not stolen during acquisition'

malformed_lock_project="$(new_project)"
mkdir -p "$malformed_lock_project/.pi/.kanban.lock"
printf '%s\n' 'not-json' > "$malformed_lock_project/.pi/.kanban.lock/owner.json"
LOCK_PATH="$malformed_lock_project/.pi/.kanban.lock" /usr/bin/python3 - <<'PY'
import os, pathlib
path = pathlib.Path(os.environ['LOCK_PATH'])
os.utime(path, (0, 0))
PY
run_pi "$malformed_lock_project" '/todo add Recovered malformed lock'
assert_run_success_contains 'Created T-001: Recovered malformed lock' 'Malformed lock files are recovered after the grace period'


zero_pid_lock_project="$(new_project)"
mkdir -p "$zero_pid_lock_project/.pi/.kanban.lock"
printf '%s\n' '{"pid":0,"token":"zero-pid","acquired_at":"2026-01-01T00:00:00Z"}' > "$zero_pid_lock_project/.pi/.kanban.lock/owner.json"
LOCK_PATH="$zero_pid_lock_project/.pi/.kanban.lock/owner.json" /usr/bin/python3 - <<'PY'
import os, pathlib
path = pathlib.Path(os.environ['LOCK_PATH'])
os.utime(path, (0, 0))
PY
run_pi "$zero_pid_lock_project" '/todo add Recovered zero pid lock'
assert_run_success_contains 'Created T-001: Recovered zero pid lock' 'pid=0 lock owners are treated as malformed'

negative_pid_lock_project="$(new_project)"
mkdir -p "$negative_pid_lock_project/.pi/.kanban.lock"
printf '%s\n' '{"pid":-1,"token":"negative-pid","acquired_at":"2026-01-01T00:00:00Z"}' > "$negative_pid_lock_project/.pi/.kanban.lock/owner.json"
LOCK_PATH="$negative_pid_lock_project/.pi/.kanban.lock/owner.json" /usr/bin/python3 - <<'PY'
import os, pathlib
path = pathlib.Path(os.environ['LOCK_PATH'])
os.utime(path, (0, 0))
PY
run_pi "$negative_pid_lock_project" '/todo add Recovered negative pid lock'
assert_run_success_contains 'Created T-001: Recovered negative pid lock' 'Negative lock owner pids are treated as malformed'


old_live_pid_lock_project="$(new_project)"
mkdir -p "$old_live_pid_lock_project/.pi/.kanban.lock"
printf '%s\n' '{"pid":1,"token":"old-live-pid","acquired_at":"2026-01-01T00:00:00Z"}' > "$old_live_pid_lock_project/.pi/.kanban.lock/owner.json"
LOCK_PATH="$old_live_pid_lock_project/.pi/.kanban.lock/owner.json" /usr/bin/python3 - <<'PY'
import os, pathlib
path = pathlib.Path(os.environ['LOCK_PATH'])
os.utime(path, (0, 0))
PY
run_pi "$old_live_pid_lock_project" '/todo add Recovered reused pid lock'
assert_run_success_contains 'Created T-001: Recovered reused pid lock' 'Ancient locks are recovered even when their pid is currently live'


printf '\n== Event append rollback ==\n'
rollback_create_project="$(new_project)"
mkdir -p "$rollback_create_project/.pi/todos/.events.ndjson"
run_pi "$rollback_create_project" '/todo add Event append failure'
assert_run_failure_contains 'EISDIR' 'Create fails when the event log append path is broken'
assert_not_exists "$rollback_create_project/.pi/todos/t-001-event-append-failure.md" 'Create rollback removes the staged task file'

rollback_mutation_project="$(new_project)"
run_pi "$rollback_mutation_project" '/todo add Rollback task'
run_pi "$rollback_mutation_project" '/kanban move T-001 ready'
rm "$rollback_mutation_project/.pi/todos/.events.ndjson"
mkdir "$rollback_mutation_project/.pi/todos/.events.ndjson"
run_pi "$rollback_mutation_project" '/kanban claim T-001'
assert_run_failure_contains 'EISDIR' 'Mutation fails when the event log append path is broken'
assert_task_meta "$rollback_mutation_project/.pi/todos/t-001-rollback-task.md" "
assert meta['status'] == 'ready'
assert 'started_at' not in meta
assert 'claimed_by_session' not in meta
assert meta['version'] == 2
" 'Mutation rollback restores prior task metadata'


printf '\n== Stale version guard ==\n'
stale_project="$(new_project)"
run_pi "$stale_project" '/todo add Versioned task'
run_pi "$stale_project" '/kanban move T-001 ready'
set +e
stale_output="$(PROJECT_DIR="$stale_project" STORE_PATH="$STORE_MODULE" bun --eval 'const mod = await import("file://" + process.env.STORE_PATH); mod.assertTaskVersion(process.env.PROJECT_DIR, "T-001", 1);' 2>&1)"
stale_status=$?
set -e
if [ "$stale_status" -ne 0 ] && [[ "$stale_output" == *'Stale write refused for T-001'* ]]; then
  pass 'Store-level version guard rejects stale expected versions'
else
  fail 'Store-level version guard rejects stale expected versions'
  printf '---- output ----\n%s\n----------------\n' "$stale_output"
fi

printf '\n== Summary ==\n'
printf 'PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
