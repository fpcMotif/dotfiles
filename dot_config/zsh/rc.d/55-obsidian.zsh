# 55-obsidian.zsh — Obsidian vault management, headless sync, quick notes

export OBSIDIAN_VAULT="$HOME/Documents/obsidian"
alias obsidian="ob"
alias ob-remote="ob sync-list-remote"
alias ob-local="ob sync-list-local"
alias ob-status="ob sync-status"
alias ob-config="ob sync-config"
alias ob-sync="ob sync"
alias ob-watch="ob sync --continuous"

# ── Notes CLI ────────────────────────────────────────────────────────────────
alias note="notesmd-cli"
alias note-daily="notesmd-cli daily --editor"
alias note-new="notesmd-cli create --editor"
alias note-find="notesmd-cli search"
alias note-find-content="notesmd-cli search-content"
alias note-ls="notesmd-cli list"
alias note-open="notesmd-cli open --editor"

jot() {
  local msg="$*"
  local daily_path
  daily_path="$(notesmd-cli daily --print-path)" || return 1
  echo "- $msg" >> "$daily_path" && echo "Noted to $daily_path"
}

# ── OpenCode Vault Shortcuts ─────────────────────────────────────────────────
oc-vault() { opencode "$OBSIDIAN_VAULT"; }
oc-study() { opencode "$OBSIDIAN_VAULT/Learning"; }
oc-daily() {
  local daily_path
  daily_path="$(notesmd-cli daily --print-path)" || return 1
  opencode "$daily_path"
}
oc-note() {
  local note_path
  note_path="$(notesmd-cli create --print-path "$@")" || return 1
  opencode "$note_path"
}

# ── Obsidian Headless Sync (launchd) ─────────────────────────────────────────
OBS_PLIST="$HOME/Library/LaunchAgents/com.f.obsidian-headless.sync.plist"
OBS_SVC="gui/$(id -u)/com.f.obsidian-headless.sync"

obd-load() {
  [[ -f "$OBS_PLIST" ]] || { echo "Error: plist not found" >&2; return 1; }
  launchctl bootstrap "gui/$(id -u)" "$OBS_PLIST" || { echo "Error: load failed" >&2; return 1; }
}
obd-start() {
  [[ -f "$OBS_PLIST" ]] || { echo "Error: plist not found" >&2; return 1; }
  launchctl bootstrap "gui/$(id -u)" "$OBS_PLIST" 2>/dev/null || true
  launchctl kickstart -k "$OBS_SVC" || { echo "Error: start failed" >&2; return 1; }
}
obd-stop() {
  launchctl print "$OBS_SVC" >/dev/null 2>&1 || { echo "Error: service not found" >&2; return 1; }
  launchctl bootout "$OBS_SVC" || { echo "Error: stop failed" >&2; return 1; }
}
obd-reload() {
  [[ -f "$OBS_PLIST" ]] || { echo "Error: plist not found" >&2; return 1; }
  launchctl bootout "$OBS_SVC" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$OBS_PLIST" || { echo "Error: load failed" >&2; return 1; }
  launchctl kickstart -k "$OBS_SVC" || { echo "Error: start failed" >&2; return 1; }
}
obd-status() { launchctl print "$OBS_SVC"; }
ob-log() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stdout.log"; }
ob-err() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stderr.log"; }
vault() { open "$OBSIDIAN_VAULT"; }
