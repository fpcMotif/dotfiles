#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin:/opt/zerobrew/prefix/bin:$PATH"
export NODE_PATH="/Users/f/.bun/install/global/node_modules"

pass_count=0
fail_count=0

pass() {
  printf 'PASS  %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  fail_count=$((fail_count + 1))
}

run_logic_case() {
  local label="$1"
  local mode="$2"
  local source_path="$3"
  if SOURCE_PATH="$source_path" VERIFY_MODE="$mode" bun --eval '
const sourcePath = process.env.SOURCE_PATH;
const verifyMode = process.env.VERIFY_MODE;
if (!sourcePath || !verifyMode) throw new Error("missing verification env");

const { KeybindingsManager } = await import("file:///Users/f/.bun/install/global/node_modules/@mariozechner/pi-coding-agent/dist/core/keybindings.js");
let modulePath = sourcePath;
let cleanupPath;
if (verifyMode === "translated") {
  const source = await Bun.file(sourcePath).text();
  const translated = source
    .replaceAll("@oh-my-pi/pi-coding-agent", "@mariozechner/pi-coding-agent")
    .replaceAll("@oh-my-pi/pi-tui", "@mariozechner/pi-tui");
  cleanupPath = `/tmp/omp-vim-input-${Date.now()}-${Math.random().toString(16).slice(2)}.ts`;
  await Bun.write(cleanupPath, translated);
  modulePath = cleanupPath;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function createEditor(VimEditor, keybindings, labels) {
  const tui = { requestRender() {}, terminal: { rows: 40 } };
  const theme = { borderColor: (value) => value, selectList: {} };
  return new VimEditor(tui, theme, keybindings, (label) => labels.push(label));
}

try {
  const { VimEditor } = await import(`file://${modulePath}`);
  const keybindings = KeybindingsManager.inMemory({});

  const labels = [];
  const lineEditor = createEditor(VimEditor, keybindings, labels);
  lineEditor.setText("alpha\nbeta");
  lineEditor.handleInput("\x1b");
  lineEditor.handleInput("0");
  lineEditor.handleInput("d");
  lineEditor.handleInput("d");
  assert(lineEditor.getText() === "alpha", `dd failed: ${lineEditor.getText()}`);
  lineEditor.handleInput("p");
  assert(lineEditor.getText() === "alpha\nbeta", `linewise p failed: ${lineEditor.getText()}`);

  const charEditor = createEditor(VimEditor, keybindings, labels);
  charEditor.setText("cat");
  charEditor.handleInput("\x1b");
  charEditor.handleInput("0");
  charEditor.handleInput("x");
  assert(charEditor.getText() === "at", `x failed: ${charEditor.getText()}`);
  charEditor.handleInput("u");
  assert(charEditor.getText() === "cat", `u after x failed: ${charEditor.getText()}`);

  const insertUndoEditor = createEditor(VimEditor, keybindings, labels);
  insertUndoEditor.setText("cat");
  insertUndoEditor.handleInput("!");
  insertUndoEditor.handleInput("\x1b");
  insertUndoEditor.handleInput("u");
  assert(insertUndoEditor.getText() === "cat", `grouped insert undo failed: ${insertUndoEditor.getText()}`);

  const dwEditor = createEditor(VimEditor, keybindings, labels);
  dwEditor.setText("alpha beta");
  dwEditor.handleInput("\x1b");
  dwEditor.handleInput("0");
  dwEditor.handleInput("d");
  dwEditor.handleInput("w");
  assert(dwEditor.getText() === "beta", `dw failed: ${dwEditor.getText()}`);

  const deEditor = createEditor(VimEditor, keybindings, labels);
  deEditor.setText("alpha beta");
  deEditor.handleInput("\x1b");
  deEditor.handleInput("0");
  deEditor.handleInput("d");
  deEditor.handleInput("e");
  assert(deEditor.getText() === " beta", `de failed: ${deEditor.getText()}`);

  const dDollarEditor = createEditor(VimEditor, keybindings, labels);
  dDollarEditor.setText("alpha beta");
  dDollarEditor.handleInput("\x1b");
  dDollarEditor.handleInput("0");
  dDollarEditor.handleInput("d");
  dDollarEditor.handleInput("$");
  assert(dDollarEditor.getText() === "", `d$ failed: ${dDollarEditor.getText()}`);

  const cwEditor = createEditor(VimEditor, keybindings, labels);
  cwEditor.setText("alpha beta");
  cwEditor.handleInput("\x1b");
  cwEditor.handleInput("0");
  cwEditor.handleInput("c");
  cwEditor.handleInput("w");
  cwEditor.handleInput("Z");
  cwEditor.handleInput("\x1b");
  assert(cwEditor.getText() === "Z beta", `cw failed: ${cwEditor.getText()}`);
  cwEditor.handleInput("u");
  assert(cwEditor.getText() === "alpha beta", `u after cw failed: ${cwEditor.getText()}`);

  const jumpEditor = createEditor(VimEditor, keybindings, labels);
  jumpEditor.setText("one\ntwo\nthree");
  jumpEditor.handleInput("\x1b");
  jumpEditor.handleInput("G");
  let cursor = jumpEditor.getCursor();
  assert(cursor.line === 2 && cursor.col === 0, `G failed: ${JSON.stringify(cursor)}`);
  jumpEditor.handleInput("g");
  jumpEditor.handleInput("g");
  cursor = jumpEditor.getCursor();
  assert(cursor.line === 0 && cursor.col === 0, `gg failed: ${JSON.stringify(cursor)}`);

  const crossLineMotionEditor = createEditor(VimEditor, keybindings, labels);
  crossLineMotionEditor.setText("alpha\nbeta");
  crossLineMotionEditor.handleInput("\x1b");
  crossLineMotionEditor.handleInput("g");
  crossLineMotionEditor.handleInput("g");
  crossLineMotionEditor.handleInput("w");
  cursor = crossLineMotionEditor.getCursor();
  assert(cursor.line === 1 && cursor.col === 0, `cross-line w failed: ${JSON.stringify(cursor)}`);

  const crossLineEEditor = createEditor(VimEditor, keybindings, labels);
  crossLineEEditor.setText("alpha\nbeta");
  crossLineEEditor.handleInput("\x1b");
  crossLineEEditor.handleInput("g");
  crossLineEEditor.handleInput("g");
  crossLineEEditor.handleInput("e");
  crossLineEEditor.handleInput("e");
  cursor = crossLineEEditor.getCursor();
  assert(cursor.line === 1 && cursor.col === 3, `cross-line repeated e failed: ${JSON.stringify(cursor)}`);

  const visualDeleteEditor = createEditor(VimEditor, keybindings, labels);
  visualDeleteEditor.setText("alpha beta");
  visualDeleteEditor.handleInput("\x1b");
  visualDeleteEditor.handleInput("0");
  visualDeleteEditor.handleInput("v");
  visualDeleteEditor.handleInput("e");
  assert(labels.at(-1)?.startsWith("vim VISUAL"), `visual mode status missing: ${labels.at(-1)}`);
  visualDeleteEditor.handleInput("d");
  assert(visualDeleteEditor.getText() === " beta", `visual d failed: ${visualDeleteEditor.getText()}`);

  const visualChangeEditor = createEditor(VimEditor, keybindings, labels);
  visualChangeEditor.setText("alpha beta");
  visualChangeEditor.handleInput("\x1b");
  visualChangeEditor.handleInput("0");
  visualChangeEditor.handleInput("v");
  visualChangeEditor.handleInput("e");
  visualChangeEditor.handleInput("c");
  visualChangeEditor.handleInput("Z");
  visualChangeEditor.handleInput("\x1b");
  assert(visualChangeEditor.getText() === "Z beta", `visual c failed: ${visualChangeEditor.getText()}`);

  const visualYankEditor = createEditor(VimEditor, keybindings, labels);
  visualYankEditor.setText("alpha beta");
  visualYankEditor.handleInput("\x1b");
  visualYankEditor.handleInput("0");
  visualYankEditor.handleInput("v");
  visualYankEditor.handleInput("e");
  visualYankEditor.handleInput("y");
  visualYankEditor.handleInput("$");
  visualYankEditor.handleInput("p");
  assert(visualYankEditor.getText() === "alpha betaalpha", `visual y/p failed: ${visualYankEditor.getText()}`);

  const quoteEditor = createEditor(VimEditor, keybindings, labels);
  quoteEditor.setText("hello");
  quoteEditor.handleInput("\x1b");
  quoteEditor.handleInput("A");
  quoteEditor.handleInput("!");
  quoteEditor.handleInput("\x1b");
  assert(quoteEditor.getText() === "hello!", `A insert failed: ${quoteEditor.getText()}`);
} finally {
  if (cleanupPath) {
    await Bun.file(cleanupPath).delete();
  }
}
' >/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

printf '== Vim input verification ==\n\n'
run_logic_case 'Pi vim input logic' direct '/Users/f/.pi/agent/extensions/vim-input/index.ts'
run_logic_case 'OMP translated-source behavior check' translated '/Users/f/.omp/agent/extensions/vim-input/index.ts'

printf '\n== Summary ==\n'
printf 'PASS=%s FAIL=%s\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
