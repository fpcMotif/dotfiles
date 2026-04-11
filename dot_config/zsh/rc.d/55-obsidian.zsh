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
_obd_domain="gui/$(id -u)"
_obd_label="com.f.obsidian-headless.sync"
_obd_svc="${_obd_domain}/${_obd_label}"
_obd_plist="$HOME/Library/LaunchAgents/${_obd_label}.plist"

obd-load() {
  launchctl bootstrap "$_obd_domain" "$_obd_plist" 2>/dev/null || true
}
obd-start() {
  launchctl bootstrap "$_obd_domain" "$_obd_plist" 2>/dev/null || true
  launchctl kickstart -k "$_obd_svc"
}
obd-stop() { launchctl bootout "$_obd_svc"; }
obd-reload() {
  launchctl bootout "$_obd_svc" 2>/dev/null || true
  launchctl bootstrap "$_obd_domain" "$_obd_plist"
  launchctl kickstart -k "$_obd_svc"
}
obd-status() { launchctl print "$_obd_svc"; }
ob-log() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stdout.log"; }
ob-err() { /usr/bin/tail -n 100 -f "$HOME/Library/Logs/obsidian-headless/sync.stderr.log"; }
vault() { open "$OBSIDIAN_VAULT"; }
