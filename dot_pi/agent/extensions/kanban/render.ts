import type { BoardSnapshot, MutationResult, StoredTask, TaskStatus } from "./types";

const BOARD_COLUMNS: TaskStatus[] = ["backlog", "ready", "doing", "review", "blocked", "done"];
const ACTIVE_COLUMNS = new Set<TaskStatus>(["doing", "review", "blocked"]);

export function renderBoard(snapshot: BoardSnapshot): string {
	if (!snapshot.exists || snapshot.tasks.length === 0) {
		return "Board is empty. Use /todo add <title> to create a task.";
	}

	const grouped = new Map<TaskStatus, StoredTask[]>();
	for (const status of BOARD_COLUMNS) {
		grouped.set(status, []);
	}
	for (const task of snapshot.tasks) {
		grouped.get(task.meta.status)?.push(task);
	}

	const columnWidth = 24;
	const header = BOARD_COLUMNS.map((status) => formatColumnHeader(status, snapshot, grouped.get(status) ?? [], columnWidth)).join(" | ");
	const separator = BOARD_COLUMNS.map(() => "─".repeat(columnWidth)).join("─┼─");
	const maxRows = Math.max(1, ...BOARD_COLUMNS.map((status) => grouped.get(status)?.length ?? 0));
	const rows: string[] = [];
	for (let rowIndex = 0; rowIndex < maxRows; rowIndex += 1) {
		rows.push(
			BOARD_COLUMNS.map((status) => formatBoardCell(grouped.get(status) ?? [], rowIndex, columnWidth)).join(" | "),
		);
	}

	return [header, separator, ...rows].join("\n");
}

export function renderTaskList(tasks: StoredTask[]): string {
	if (tasks.length === 0) {
		return "No tasks found.";
	}
	return tasks.map(renderTaskLine).join("\n");
}

export function renderTaskLine(task: StoredTask): string {
	const parts = [
		`${task.meta.alias}`,
		`[${task.meta.status}]`,
		`P${task.meta.priority}`,
		sanitizeInline(task.meta.title, 120),
	];
	if (task.meta.lane) {
		parts.push(`lane:${sanitizeInline(task.meta.lane, 40)}`);
	}
	for (const tag of task.meta.tags) {
		parts.push(`#${sanitizeInline(tag, 32)}`);
	}
	if (task.meta.due_at) {
		parts.push(`due:${sanitizeInline(task.meta.due_at, 40)}`);
	}
	if (task.meta.blocked_reason) {
		parts.push(`blocked:${sanitizeInline(task.meta.blocked_reason, 80)}`);
	}
	return parts.join(" ");
}

export function renderTaskDetails(task: StoredTask): string {
	const lines = [
		`${task.meta.alias} — ${sanitizeInline(task.meta.title, 200)}`,
		`status: ${task.meta.status}`,
		`priority: ${task.meta.priority}`,
		`version: ${task.meta.version}`,
		`uuid: ${task.meta.uuid}`,
		`created_at: ${task.meta.created_at}`,
		`updated_at: ${task.meta.updated_at}`,
	];

	if (task.meta.started_at) {
		lines.push(`started_at: ${task.meta.started_at}`);
	}
	if (task.meta.finished_at) {
		lines.push(`finished_at: ${task.meta.finished_at}`);
	}
	if (task.meta.due_at) {
		lines.push(`due_at: ${sanitizeInline(task.meta.due_at, 80)}`);
	}
	if (task.meta.lane) {
		lines.push(`lane: ${sanitizeInline(task.meta.lane, 80)}`);
	}
	if (task.meta.tags.length > 0) {
		lines.push(`tags: ${task.meta.tags.map((tag) => sanitizeInline(tag, 40)).join(", ")}`);
	}
	if (task.meta.depends_on.length > 0) {
		lines.push(`depends_on: ${task.meta.depends_on.map((dep) => sanitizeInline(dep, 60)).join(", ")}`);
	}
	if (task.meta.claimed_by_session) {
		lines.push(`claimed_by_session: ${sanitizeInline(task.meta.claimed_by_session, 120)}`);
	}
	if (task.meta.blocked_reason) {
		lines.push(`blocked_reason: ${sanitizeInline(task.meta.blocked_reason, 200)}`);
	}

	return `${lines.join("\n")}\n\n${task.body}`;
}

export function renderBoardSummary(snapshot: BoardSnapshot): string {
	if (!snapshot.exists || snapshot.tasks.length === 0) {
		return "Board empty";
	}
	const counts = countTasks(snapshot);
	return BOARD_COLUMNS.map((status) => {
		const count = counts[status];
		const limit = snapshot.config.wip[status as keyof typeof snapshot.config.wip];
		return limit ? `${status} ${count}/${limit}` : `${status} ${count}`;
	}).join(" | ");
}

export function renderMutationSummary(result: MutationResult): string {
	const lines = [result.message, renderBoardSummary(result.snapshot)];
	const focus = renderFocusLines(result.snapshot);
	if (focus.length > 0) {
		lines.push(...focus);
	}
	return lines.join("\n");
}

export function renderWidgetLines(snapshot: BoardSnapshot): string[] {
	if (!snapshot.exists || snapshot.tasks.length === 0) {
		return [];
	}
	const lines = [`Kanban: ${renderBoardSummary(snapshot)}`];
	const focus = renderFocusLines(snapshot);
	return [...lines, ...focus].slice(0, 4);
}

export function renderPromptSummary(snapshot: BoardSnapshot): string | null {
	if (!snapshot.exists || snapshot.tasks.length === 0) {
		return null;
	}
	const active = snapshot.tasks.filter((task) => ACTIVE_COLUMNS.has(task.meta.status));
	const ready = snapshot.tasks.filter((task) => task.meta.status === "ready");
	if (active.length === 0 && ready.length === 0) {
		return null;
	}

	const lines = ["## Kanban Board", renderBoardSummary(snapshot), ""];
	if (active.length > 0) {
		lines.push("### Active Tasks");
		for (const task of active.slice(0, 5)) {
			lines.push(`- ${task.meta.alias} [${task.meta.status}] ${sanitizeInline(task.meta.title, 80)}`);
		}
		lines.push("");
	}
	if (ready.length > 0) {
		lines.push("### Ready Tasks");
		for (const task of ready.slice(0, 5)) {
			lines.push(`- ${task.meta.alias} P${task.meta.priority} ${sanitizeInline(task.meta.title, 80)}`);
		}
		lines.push("");
	}
	lines.push("Claim a ready task before coding, and keep task state truthful.");
	return lines.join("\n");
}

function renderFocusLines(snapshot: BoardSnapshot): string[] {
	const active = snapshot.tasks.filter((task) => ACTIVE_COLUMNS.has(task.meta.status));
	const ready = snapshot.tasks.filter((task) => task.meta.status === "ready");
	const lines: string[] = [];
	if (active.length > 0) {
		lines.push(`Active: ${active.slice(0, 3).map((task) => compactTaskLabel(task, 40)).join(" | ")}`);
	}
	if (ready.length > 0) {
		lines.push(`Ready: ${ready.slice(0, 3).map((task) => compactTaskLabel(task, 40)).join(" | ")}`);
	}
	return lines;
}

function countTasks(snapshot: BoardSnapshot): Record<TaskStatus, number> {
	return snapshot.tasks.reduce<Record<TaskStatus, number>>(
		(counts, task) => {
			counts[task.meta.status] += 1;
			return counts;
		},
		{ backlog: 0, ready: 0, doing: 0, review: 0, blocked: 0, done: 0 },
	);
}

function formatColumnHeader(status: TaskStatus, snapshot: BoardSnapshot, tasks: StoredTask[], width: number): string {
	const limit = snapshot.config.wip[status as keyof typeof snapshot.config.wip];
	const label = limit ? `${status.toUpperCase()} (${tasks.length}/${limit})` : `${status.toUpperCase()} (${tasks.length})`;
	return pad(label, width);
}

function formatBoardCell(tasks: StoredTask[], rowIndex: number, width: number): string {
	const task = tasks[rowIndex];
	if (!task) {
		return " ".repeat(width);
	}
	const cell = `${task.meta.alias} ${sanitizeInline(task.meta.title, width)}`;
	return truncate(cell, width);
}

function compactTaskLabel(task: StoredTask, maxLength: number): string {
	return truncateInline(`${task.meta.alias} ${task.meta.title}`, maxLength);
}

function truncate(value: string, width: number): string {
	if (value.length > width) {
		return `${value.slice(0, width - 1)}…`;
	}
	return pad(value, width);
}

function pad(value: string, width: number): string {
	return value.padEnd(width, " ");
}

function truncateInline(value: string, maxLength: number): string {
	const normalized = sanitizeInline(value, maxLength);
	return normalized.length > maxLength ? `${normalized.slice(0, maxLength - 1)}…` : normalized;
}

function sanitizeInline(value: string, maxLength: number): string {
	const normalized = value.replace(/[\r\n\t]+/g, " ").replace(/\s{2,}/g, " ").trim();
	if (normalized.length <= maxLength) {
		return normalized;
	}
	return `${normalized.slice(0, maxLength - 1)}…`;
}
