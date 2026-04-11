#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin:/opt/zerobrew/prefix/bin:$PATH"

echo "== Pi Agent Setup =="

# Ensure bun is available
if ! command -v bun >/dev/null 2>&1; then
  echo "ERROR: bun not found. Install from https://bun.sh"
  exit 1
fi

# Install global tools via bun
echo "Installing global tools..."
bun add -g parallel-web-cli 2>/dev/null || echo "WARN: parallel-web-cli install failed"

# Ensure directories exist
mkdir -p "$HOME/.pi/agent/extensions"
mkdir -p "$HOME/.pi/agent/skills"
mkdir -p "$HOME/.pi/agent/scripts"

# Link skills
echo "Linking skills..."
cd "$HOME/.pi/agent/skills"
for skill in oracle stitch-mcp ast-grep gh-fix-ci gh-address-comments github-mcp modern-bash figma doc crush linear manim-skill mgrep lazygit agent-browser qmd remotion notebooklm every-team-compounding; do
  if [ -d "$HOME/.agent/skills/$skill" ] && [ ! -e "$skill" ]; then
    ln -sf "$HOME/.agent/skills/$skill" "$skill"
    echo "  linked: $skill"
  fi
done

echo ""
echo "Setup complete. Run smoke test with:"
echo "  bash ~/.pi/agent/scripts/smoke-test.sh"
