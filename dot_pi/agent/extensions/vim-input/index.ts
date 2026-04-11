import type { ExtensionAPI, KeybindingsManager } from "@mariozechner/pi-coding-agent";
import { CustomEditor } from "@mariozechner/pi-coding-agent";
import { matchesKey } from "@mariozechner/pi-tui";

type VimMode = "insert" | "normal" | "visual";
type PendingAction = "d" | "c" | "g" | null;
type CursorPosition = { line: number; col: number };
type BufferSnapshot = { text: string; cursor: CursorPosition };
type BufferState = { text: string; lines: string[]; cursor: CursorPosition; index: number };
type TextRange = { start: number; end: number };
type VimRegister =
	| { kind: "char"; text: string }
	| { kind: "line"; text: string }
	| null;

const CTRL_A = "\x01";
const CTRL_E = "\x05";
const CTRL_B = "\x02";
const CTRL_F = "\x06";
const ALT_B = "\x1bb";
const ALT_F = "\x1bf";
const UP = "\x1b[A";
const DOWN = "\x1b[B";

const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

export class VimEditor extends CustomEditor {
	#mode: VimMode = "insert";
	#pendingAction: PendingAction = null;
	#visualAnchor: number | null = null;
	#register: VimRegister = null;
	#undoStack: BufferSnapshot[] = [];
	#insertBaseline: BufferSnapshot | null = null;
	#onModeChange?: (label: string) => void;

	constructor(tui: unknown, theme: unknown, keybindings: KeybindingsManager, onModeChange?: (label: string) => void) {
		super(tui as never, theme as never, keybindings);
		this.#onModeChange = onModeChange;
		this.#publishMode();
	}

	override handleInput(data: string): void {
		if (this.#mode === "insert") {
			this.#handleInsertInput(data);
			return;
		}

		if (matchesKey(data, "escape") || matchesKey(data, "esc")) {
			this.#pendingAction = null;
			if (this.#mode === "visual") {
				this.#leaveVisualMode();
			} else {
				this.#publishMode();
			}
			return;
		}

		if (this.#pendingAction) {
			this.#handlePendingAction(data);
			return;
		}

		if (this.#mode === "visual") {
			if (this.#handleVisualCommand(data)) {
				return;
			}
		} else if (this.#handleNormalCommand(data)) {
			return;
		}

		if (isPlainTextKey(data)) {
			return;
		}

		super.handleInput(data);
		this.#publishMode();
	}

	#handleInsertInput(data: string): void {
		if (matchesKey(data, "escape") || matchesKey(data, "esc")) {
			if (this.isShowingAutocomplete()) {
				super.handleInput(data);
				return;
			}
			this.#mode = "normal";
			this.#pendingAction = null;
			this.#visualAnchor = null;
			this.#finalizeInsertUndo();
			this.#publishMode();
			return;
		}

		const before = this.#snapshot();
		super.handleInput(data);
		if (before.text !== this.getText() && !this.#insertBaseline) {
			this.#insertBaseline = before;
		}
		this.#publishMode();
	}

	#handlePendingAction(data: string): void {
		const pending = this.#pendingAction;
		this.#pendingAction = null;

		if (pending === "g") {
			if (data === "g") {
				this.#moveToLine(0, 0);
				return;
			}
			this.handleInput(data);
			return;
		}

		if (pending === "d") {
			if (data === "d") {
				this.#deleteCurrentLine();
				return;
			}
			if (this.#applyOperatorMotion("delete", data)) {
				return;
			}
			this.handleInput(data);
			return;
		}

		if (pending === "c") {
			if (data === "c") {
				this.#changeCurrentLine();
				return;
			}
			if (this.#applyOperatorMotion("change", data)) {
				return;
			}
			this.handleInput(data);
		}
	}

	#feed(sequence: string): void {
		super.handleInput(sequence);
	}

	#handleNormalCommand(data: string): boolean {
		switch (data) {
			case "i":
				this.#enterInsert(this.#snapshot());
				return true;
			case "a":
				this.#feed(CTRL_F);
				this.#enterInsert(this.#snapshot());
				return true;
			case "I":
				this.#feed(CTRL_A);
				this.#enterInsert(this.#snapshot());
				return true;
			case "A":
				this.#feed(CTRL_E);
				this.#enterInsert(this.#snapshot());
				return true;
			case "o":
				this.#openLineBelow();
				return true;
			case "h":
				this.#feed(CTRL_B);
				this.#publishMode();
				return true;
			case "j":
				this.#feed(DOWN);
				this.#publishMode();
				return true;
			case "k":
				this.#feed(UP);
				this.#publishMode();
				return true;
			case "l":
				this.#feed(CTRL_F);
				this.#publishMode();
				return true;
			case "0":
				this.#feed(CTRL_A);
				this.#publishMode();
				return true;
			case "$":
				this.#moveToLineEndCharacter();
				return true;
			case "w":
				this.#moveToIndex(findNextWordStart(this.#buffer()));
				return true;
			case "b":
				this.#moveToIndex(findPreviousWordStart(this.#buffer()));
				return true;
			case "e":
				this.#moveToWordEnd();
				return true;
			case "x":
				this.#deleteCharUnderCursor();
				return true;
			case "d":
				this.#pendingAction = "d";
				this.#publishMode();
				return true;
			case "c":
				this.#pendingAction = "c";
				this.#publishMode();
				return true;
			case "g":
				this.#pendingAction = "g";
				this.#publishMode();
				return true;
			case "G":
				this.#moveToLine(this.getLines().length - 1, 0);
				return true;
			case "v":
				this.#mode = "visual";
				this.#visualAnchor = this.#buffer().index;
				this.#publishMode();
				return true;
			case "p":
				this.#pasteRegister();
				return true;
			case "u":
				this.#undo();
				return true;
		}

		return false;
	}

	#handleVisualCommand(data: string): boolean {
		switch (data) {
			case "v":
				this.#leaveVisualMode();
				return true;
			case "h":
				this.#feed(CTRL_B);
				this.#publishMode();
				return true;
			case "j":
				this.#feed(DOWN);
				this.#publishMode();
				return true;
			case "k":
				this.#feed(UP);
				this.#publishMode();
				return true;
			case "l":
				this.#feed(CTRL_F);
				this.#publishMode();
				return true;
			case "0":
				this.#feed(CTRL_A);
				this.#publishMode();
				return true;
			case "$":
				this.#moveToLineEndCharacter();
				return true;
			case "w":
				this.#moveToIndex(findNextWordStart(this.#buffer()));
				return true;
			case "b":
				this.#moveToIndex(findPreviousWordStart(this.#buffer()));
				return true;
			case "e":
				this.#moveToWordEnd();
				return true;
			case "g":
				this.#pendingAction = "g";
				this.#publishMode();
				return true;
			case "G":
				this.#moveToLine(this.getLines().length - 1, 0);
				return true;
			case "d":
				this.#deleteVisualSelection(false);
				return true;
			case "c":
				this.#deleteVisualSelection(true);
				return true;
			case "y":
				this.#yankVisualSelection();
				return true;
			case "u":
				this.#undo();
				return true;
		}

		return false;
	}

	#applyOperatorMotion(kind: "delete" | "change", motion: string): boolean {
		const buffer = this.#buffer();
		let range: TextRange | null = null;
		if (motion === "w") {
			range = kind === "change" ? changeWordRange(buffer) : deleteWordRange(buffer);
		} else if (motion === "e") {
			range = deleteToWordEndRange(buffer);
		} else if (motion === "$") {
			range = deleteToLineEndRange(buffer);
		}
		if (!range || range.end <= range.start) {
			this.#publishMode();
			return true;
		}

		const snapshot = this.#snapshot();
		const nextText = buffer.text.slice(0, range.start) + buffer.text.slice(range.end);
		this.#register = { kind: "char", text: buffer.text.slice(range.start, range.end) };
		this.#replaceText(nextText, range.start);
		if (kind === "change") {
			this.#enterInsert(snapshot);
		} else {
			this.#undoStack.push(snapshot);
			this.#mode = "normal";
			this.#visualAnchor = null;
			this.#publishMode();
		}
		return true;
	}

	#deleteCharUnderCursor(): void {
		const buffer = this.#buffer();
		const length = graphemeLengthAt(buffer.text, buffer.index);
		if (length <= 0) {
			return;
		}
		const snapshot = this.#snapshot();
		this.#register = { kind: "char", text: buffer.text.slice(buffer.index, buffer.index + length) };
		const nextText = buffer.text.slice(0, buffer.index) + buffer.text.slice(buffer.index + length);
		this.#undoStack.push(snapshot);
		this.#replaceText(nextText, buffer.index);
		this.#mode = "normal";
		this.#visualAnchor = null;
		this.#publishMode();
	}

	#deleteCurrentLine(): void {
		const lines = this.getLines();
		const cursor = this.getCursor();
		const snapshot = this.#snapshot();
		this.#register = { kind: "line", text: lines[cursor.line] ?? "" };
		if (lines.length === 1) {
			this.#undoStack.push(snapshot);
			this.#replaceText("", 0);
			this.#mode = "normal";
			this.#visualAnchor = null;
			this.#publishMode();
			return;
		}
		const nextLines = [...lines.slice(0, cursor.line), ...lines.slice(cursor.line + 1)];
		const nextLine = Math.min(cursor.line, nextLines.length - 1);
		const nextIndex = indexFromPosition(nextLines, { line: nextLine, col: 0 });
		this.#undoStack.push(snapshot);
		this.#replaceText(nextLines.join("\n"), nextIndex);
		this.#mode = "normal";
		this.#visualAnchor = null;
		this.#publishMode();
	}

	#changeCurrentLine(): void {
		const lines = this.getLines();
		const cursor = this.getCursor();
		const snapshot = this.#snapshot();
		this.#register = { kind: "line", text: lines[cursor.line] ?? "" };
		const nextLines = [...lines];
		nextLines[cursor.line] = "";
		const nextIndex = indexFromPosition(nextLines, { line: cursor.line, col: 0 });
		this.#replaceText(nextLines.join("\n"), nextIndex);
		this.#enterInsert(snapshot);
	}

	#openLineBelow(): void {
		const lines = this.getLines();
		const cursor = this.getCursor();
		const snapshot = this.#snapshot();
		const nextLines = [...lines];
		nextLines.splice(cursor.line + 1, 0, "");
		const nextIndex = indexFromPosition(nextLines, { line: cursor.line + 1, col: 0 });
		this.#replaceText(nextLines.join("\n"), nextIndex);
		this.#enterInsert(snapshot);
	}

	#pasteRegister(): void {
		if (!this.#register) {
			return;
		}
		const snapshot = this.#snapshot();
		if (this.#register.kind === "line") {
			const lines = this.getLines();
			const cursor = this.getCursor();
			const nextLines = [...lines];
			nextLines.splice(cursor.line + 1, 0, this.#register.text);
			const nextIndex = indexFromPosition(nextLines, { line: cursor.line + 1, col: 0 });
			this.#undoStack.push(snapshot);
			this.#replaceText(nextLines.join("\n"), nextIndex);
			this.#mode = "normal";
			this.#visualAnchor = null;
			this.#publishMode();
			return;
		}

		const buffer = this.#buffer();
		const insertAt = Math.min(buffer.text.length, buffer.index + graphemeLengthAt(buffer.text, buffer.index));
		const nextText = buffer.text.slice(0, insertAt) + this.#register.text + buffer.text.slice(insertAt);
		this.#undoStack.push(snapshot);
		this.#replaceText(nextText, insertAt + this.#register.text.length);
		this.#mode = "normal";
		this.#visualAnchor = null;
		this.#publishMode();
	}

	#deleteVisualSelection(change: boolean): void {
		const buffer = this.#buffer();
		const selection = currentSelection(buffer.text, this.#visualAnchor, buffer.index);
		if (!selection || selection.end <= selection.start) {
			this.#leaveVisualMode();
			return;
		}
		const snapshot = this.#snapshot();
		this.#register = { kind: "char", text: buffer.text.slice(selection.start, selection.end) };
		const nextText = buffer.text.slice(0, selection.start) + buffer.text.slice(selection.end);
		this.#replaceText(nextText, selection.start);
		if (change) {
			this.#enterInsert(snapshot);
			return;
		}
		this.#undoStack.push(snapshot);
		this.#mode = "normal";
		this.#visualAnchor = null;
		this.#publishMode();
	}

	#yankVisualSelection(): void {
		const buffer = this.#buffer();
		const selection = currentSelection(buffer.text, this.#visualAnchor, buffer.index);
		if (selection && selection.end > selection.start) {
			this.#register = { kind: "char", text: buffer.text.slice(selection.start, selection.end) };
		}
		this.#leaveVisualMode();
	}

	#undo(): void {
		this.#insertBaseline = null;
		const snapshot = this.#undoStack.pop();
		if (!snapshot) {
			this.#mode = "normal";
			this.#visualAnchor = null;
			this.#pendingAction = null;
			this.#publishMode();
			return;
		}
		this.#mode = "normal";
		this.#visualAnchor = null;
		this.#pendingAction = null;
		this.#replaceText(snapshot.text, indexFromPosition(splitLines(snapshot.text), snapshot.cursor));
		this.#publishMode();
	}

	#moveToWordEnd(): void {
		const buffer = this.#buffer();
		let endExclusive = findWordEndExclusive(buffer.text, buffer.index);
		if (endExclusive <= 0) {
			return;
		}
		let target = previousGraphemeStart(buffer.text, endExclusive);
		if (target === buffer.index) {
			const probe = Math.min(buffer.text.length, buffer.index + Math.max(1, graphemeLengthAt(buffer.text, buffer.index)));
			endExclusive = findWordEndExclusive(buffer.text, probe);
			target = previousGraphemeStart(buffer.text, endExclusive);
		}
		this.#moveToIndex(target);
	}

	#moveToLineEndCharacter(): void {
		const buffer = this.#buffer();
		this.#moveToIndex(lineEndCharacterIndex(buffer.lines, buffer.cursor.line));
	}

	#moveToIndex(index: number): void {
		this.#replaceText(this.getText(), index);
		this.#publishMode();
	}

	#moveToLine(line: number, col: number): void {
		const lines = splitLines(this.getText());
		const clampedLine = Math.max(0, Math.min(line, lines.length - 1));
		const clampedCol = Math.max(0, Math.min(col, lines[clampedLine]?.length ?? 0));
		this.#replaceText(this.getText(), indexFromPosition(lines, { line: clampedLine, col: clampedCol }));
		this.#publishMode();
	}

	#replaceText(text: string, cursorIndex: number): void {
		const lines = splitLines(text);
		const clampedIndex = clampIndex(lines, cursorIndex);
		this.setText(lines.join("\n"));
		this.#moveCursor(indexToPosition(lines, clampedIndex), lines);
	}

	#moveCursor(target: CursorPosition, lines: string[]): void {
		const clampedLine = Math.max(0, Math.min(target.line, lines.length - 1));
		const clampedCol = Math.max(0, Math.min(target.col, lines[clampedLine]?.length ?? 0));
		this.#feed(CTRL_A);
		for (let line = lines.length - 1; line > clampedLine; line -= 1) {
			this.#feed(UP);
		}
		for (let column = 0; column < clampedCol; column += 1) {
			this.#feed(CTRL_F);
		}
	}

	#enterInsert(snapshot: BufferSnapshot): void {
		this.#mode = "insert";
		this.#pendingAction = null;
		this.#visualAnchor = null;
		this.#insertBaseline = snapshot;
		this.#publishMode();
	}

	#leaveVisualMode(): void {
		const buffer = this.#buffer();
		const selection = currentSelection(buffer.text, this.#visualAnchor, buffer.index);
		this.#mode = "normal";
		this.#pendingAction = null;
		if (selection) {
			this.#replaceText(buffer.text, selection.start);
		}
		this.#visualAnchor = null;
		this.#publishMode();
	}

	#finalizeInsertUndo(): void {
		if (this.#insertBaseline && this.#insertBaseline.text !== this.getText()) {
			this.#undoStack.push(this.#insertBaseline);
		}
		this.#insertBaseline = null;
	}

	#buffer(): BufferState {
		const text = this.getText();
		const lines = splitLines(text);
		const cursor = this.getCursor();
		return { text, lines, cursor, index: indexFromPosition(lines, cursor) };
	}

	#snapshot(): BufferSnapshot {
		return { text: this.getText(), cursor: this.getCursor() };
	}

	#publishMode(): void {
		if (this.#mode === "visual") {
			const buffer = this.#buffer();
			const selection = currentSelection(buffer.text, this.#visualAnchor, buffer.index);
			const count = selection ? countGraphemes(buffer.text.slice(selection.start, selection.end)) : 0;
			this.#onModeChange?.(count > 0 ? `vim VISUAL ${count}c` : "vim VISUAL");
			return;
		}
		const suffix = this.#pendingAction ? ` ${this.#pendingAction}` : "";
		this.#onModeChange?.(`vim ${this.#mode.toUpperCase()}${suffix}`);
	}
}

function splitLines(text: string): string[] {
	const lines = text.split("\n");
	return lines.length > 0 ? lines : [""];
}

function indexFromPosition(lines: string[], cursor: CursorPosition): number {
	let index = 0;
	for (let line = 0; line < cursor.line; line += 1) {
		index += (lines[line] ?? "").length + 1;
	}
	return index + cursor.col;
}

function indexToPosition(lines: string[], index: number): CursorPosition {
	let remaining = clampIndex(lines, index);
	for (let line = 0; line < lines.length; line += 1) {
		const length = (lines[line] ?? "").length;
		if (remaining <= length) {
			return { line, col: remaining };
		}
		remaining -= length + 1;
	}
	const lastLine = Math.max(0, lines.length - 1);
	return { line: lastLine, col: lines[lastLine]?.length ?? 0 };
}

function clampIndex(lines: string[], index: number): number {
	const total = lines.reduce((sum, line, lineIndex) => sum + line.length + (lineIndex < lines.length - 1 ? 1 : 0), 0);
	return Math.max(0, Math.min(index, total));
}

function currentSelection(text: string, anchor: number | null, cursor: number): TextRange | null {
	if (anchor === null) {
		return null;
	}
	const anchorEnd = anchor + graphemeLengthAt(text, anchor);
	const cursorEnd = cursor + graphemeLengthAt(text, cursor);
	return {
		start: Math.min(anchor, cursor),
		end: Math.max(anchorEnd, cursorEnd),
	};
}

function graphemeLengthAt(text: string, index: number): number {
	return [...segmenter.segment(text.slice(index))][0]?.segment.length ?? 0;
}

function previousGraphemeStart(text: string, index: number): number {
	if (index <= 0) {
		return 0;
	}
	const graphemes = [...segmenter.segment(text.slice(0, index))];
	return graphemes[graphemes.length - 1]?.index ?? 0;
}

function classifyCharacter(character: string | undefined): "space" | "word" | "punct" {
	if (!character || /\s/.test(character)) {
		return "space";
	}
	if (/[A-Za-z0-9_]/.test(character)) {
		return "word";
	}
	return "punct";
}

function findNextWordStart(buffer: BufferState): number {
	const text = buffer.text;
	let index = buffer.index;
	if (index >= text.length) {
		return text.length;
	}
	let category = classifyCharacter(text[index]);
	if (category !== "space") {
		while (index < text.length && classifyCharacter(text[index]) === category) {
			index += 1;
		}
	}
	while (index < text.length && classifyCharacter(text[index]) === "space") {
		index += 1;
	}
	return index;
}

function findPreviousWordStart(buffer: BufferState): number {
	const text = buffer.text;
	if (buffer.index <= 0) {
		return 0;
	}
	let index = buffer.index - 1;
	while (index > 0 && classifyCharacter(text[index]) === "space") {
		index -= 1;
	}
	const category = classifyCharacter(text[index]);
	while (index > 0 && classifyCharacter(text[index - 1]) === category && category !== "space") {
		index -= 1;
	}
	return index;
}

function findWordEndExclusive(text: string, index: number): number {
	if (index >= text.length) {
		return text.length;
	}
	let cursor = index;
	while (cursor < text.length && classifyCharacter(text[cursor]) === "space") {
		cursor += 1;
	}
	if (cursor >= text.length) {
		return text.length;
	}
	const category = classifyCharacter(text[cursor]);
	while (cursor < text.length && classifyCharacter(text[cursor]) === category && category !== "space") {
		cursor += 1;
	}
	return cursor;
}

function deleteWordRange(buffer: BufferState): TextRange {
	return { start: buffer.index, end: findNextWordStart(buffer) };
}

function changeWordRange(buffer: BufferState): TextRange {
	const currentCategory = classifyCharacter(buffer.text[buffer.index]);
	if (currentCategory === "space") {
		return deleteWordRange(buffer);
	}
	return { start: buffer.index, end: findWordEndExclusive(buffer.text, buffer.index) };
}

function deleteToWordEndRange(buffer: BufferState): TextRange {
	return { start: buffer.index, end: findWordEndExclusive(buffer.text, buffer.index) };
}

function lineEndCharacterIndex(lines: string[], lineIndex: number): number {
	const line = lines[lineIndex] ?? "";
	if (line.length === 0) {
		return indexFromPosition(lines, { line: lineIndex, col: 0 });
	}
	return indexFromPosition(lines, { line: lineIndex, col: previousGraphemeStart(line, line.length) });
}

function deleteToLineEndRange(buffer: BufferState): TextRange {
	const line = buffer.lines[buffer.cursor.line] ?? "";
	return {
		start: buffer.index,
		end: indexFromPosition(buffer.lines, { line: buffer.cursor.line, col: line.length }),
	};
}

function countGraphemes(text: string): number {
	return [...segmenter.segment(text)].length;
}

function isPlainTextKey(data: string): boolean {
	return data.length === 1 && data >= " " && data !== "\x7f";
}

function installVimEditor(ctx: { hasUI?: boolean; ui: { setEditorComponent: Function; setStatus: Function } }): void {
	if (!ctx.hasUI) {
		return;
	}
	ctx.ui.setEditorComponent((tui: unknown, theme: unknown, keybindings: KeybindingsManager) => {
		return new VimEditor(tui, theme, keybindings, label => ctx.ui.setStatus("vim-input", label));
	});
	ctx.ui.setStatus("vim-input", "vim INSERT");
}

export default function vimInputExtension(pi: ExtensionAPI): void {
	const apply = async (_event: unknown, ctx: { hasUI?: boolean; ui: { setEditorComponent: Function; setStatus: Function } }) => {
		installVimEditor(ctx);
	};

	pi.on("session_start", apply);
	pi.on("session_switch", apply);
	pi.on("session_fork", apply);
	pi.on("session_tree", apply);
}
