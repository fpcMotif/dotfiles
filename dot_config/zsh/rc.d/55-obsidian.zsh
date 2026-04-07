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
obd-load() {
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.f.obsidian-headless.sync.plist" 2>/dev/null || true
}
obd-start() {
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.f.obsidian-headless.sync.plist" 2>/dev/null || true
  launchctl kickstart -k "gui/$(id -u)/com.f.obsidian-headless.sync"
}
obd-stop() { launchctl bootout "gui/$(id -u)/com.f.obsidian-headless.sync"; }
obd-reload() {
  launchctl bootout "gui/$(id -u)/com.f.obsidian-headless.sync" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.f.obsidian-headless.sync.plist"
  launchctl kickstart -k "gui/$(id -u)/com.f.obsidian-headless.sync"
}
obd-status() { launchctl print "gui/$(id -u)/com.f.obsidian-headless.sync"; }
ob-log() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stdout.log"; }
ob-err() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stderr.log"; }
vault() { open "$OBSIDIAN_VAULT"; }
