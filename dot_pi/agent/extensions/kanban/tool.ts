import { basename } from "node:path";
import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { syncKanbanUi } from "./hooks";
import { renderBoard, renderMutationSummary, renderTaskDetails, renderTaskList } from "./render";
import { TASK_STATUSES } from "./types";
import { blockTask, claimTask, completeTask, createTask, listTasks, loadBoard, moveTask, showTask, unblockTask } from "./store";
import { isTaskStatus } from "./schema";

const KanbanAction = StringEnum(["list", "add", "move", "claim", "block", "unblock", "done", "show"] as const);
const KanbanStatus = StringEnum(TASK_STATUSES);

const KanbanParams = Type.Object({
	action: KanbanAction,
	id: Type.Optional(Type.String({ description: "Task alias (for example T-001) or uuid" })),
	title: Type.Optional(Type.String({ description: "Task title for add" })),
	status: Type.Optional(KanbanStatus),
	priority: Type.Optional(Type.Integer({ minimum: 1, maximum: 9 })),
	tags: Type.Optional(Type.Array(Type.String())),
	lane: Type.Optional(Type.String()),
	due: Type.Optional(Type.String({ description: "Optional due date or timestamp" })),
	reason: Type.Optional(Type.String({ description: "Required for block" })),
	filter: Type.Optional(Type.String({ description: "Optional list filter: <status>, lane:<lane>, or tag:<tag>" })),
});

interface KanbanToolDetails {
	action: "list" | "add" | "move" | "claim" | "block" | "unblock" | "done" | "show" | "summary";
	summary: string;
	changed: boolean;
	boardExists: boolean;
	migrated?: boolean;
	taskAlias?: string;
}

export function registerKanbanTools(pi: ExtensionAPI): void {
	pi.registerTool({
		name: "kanban",
		label: "Kanban",
		description: "Inspect and mutate the project-local kanban board under .pi/todos.",
		promptSnippet: "List or update project tasks in .pi/todos with explicit actions.",
		promptGuidelines: [
			"Use this tool instead of editing .pi/todos files directly when you need board state or task mutations.",
			"Claim ready work before coding, and keep blocked or done states truthful.",
		],
		parameters: KanbanParams,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const sessionId = sessionIdFor(ctx);
			switch (params.action) {
				case "list": {
					const { snapshot, tasks } = listTasks(ctx.cwd, parseFilter(params.filter), { migrateLegacy: true });
					syncKanbanUi(ctx, snapshot);
					const summary = joinWithMigrationNotice(snapshot.migrated, renderTaskList(tasks));
					return buildResult({
						action: "list",
						summary,
						changed: false,
						boardExists: snapshot.exists,
						migrated: snapshot.migrated,
					});
				}
				case "show": {
					const id = requireId(params.id, "show");
					const { snapshot, task } = showTask(ctx.cwd, id, { migrateLegacy: true });
					syncKanbanUi(ctx, snapshot);
					const summary = joinWithMigrationNotice(snapshot.migrated, renderTaskDetails(task));
					return buildResult({
						action: "show",
						summary,
						changed: false,
						boardExists: snapshot.exists,
						migrated: snapshot.migrated,
						taskAlias: task.meta.alias,
					});
				}
				case "add": {
					if (!params.title?.trim()) {
						throw new Error("kanban add requires a title");
					}
					const result = createTask(ctx.cwd, {
						title: params.title,
						priority: params.priority,
						tags: params.tags,
						lane: params.lane,
						due_at: params.due,
					}, sessionId);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "add",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
				case "claim": {
					const id = requireId(params.id, "claim");
					const result = claimTask(ctx.cwd, id, sessionId);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "claim",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
				case "move": {
					const id = requireId(params.id, "move");
					if (!isTaskStatus(params.status)) {
						throw new Error("kanban move requires a valid target status");
					}
					const result = moveTask(ctx.cwd, id, params.status, sessionId);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "move",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
				case "block": {
					const id = requireId(params.id, "block");
					if (!params.reason?.trim()) {
						throw new Error("kanban block requires a reason");
					}
					const result = blockTask(ctx.cwd, id, params.reason, sessionId);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "block",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
				case "unblock": {
					const id = requireId(params.id, "unblock");
					if (params.status !== undefined && (!isTaskStatus(params.status) || params.status === "blocked" || params.status === "done")) {
						throw new Error("kanban unblock target must be backlog, ready, doing, or review");
					}
					const result = unblockTask(ctx.cwd, id, sessionId, params.status);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "unblock",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
				case "done": {
					const id = requireId(params.id, "done");
					const result = completeTask(ctx.cwd, id, sessionId);
					syncKanbanUi(ctx, result.snapshot);
					return buildResult({
						action: "done",
						summary: renderMutationSummary(result),
						changed: result.changed,
						boardExists: result.snapshot.exists,
						taskAlias: result.task.meta.alias,
					});
				}
			}
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("kanban ")) + theme.fg("muted", args.action);
			if (args.id) {
				text += ` ${theme.fg("accent", args.id)}`;
			}
			if (args.status) {
				text += ` ${theme.fg("muted", `→ ${args.status}`)}`;
			}
			if (args.title) {
				text += ` ${theme.fg("dim", `\"${args.title}\"`)}`;
			}
			return new Text(text, 0, 0);
		},
		renderResult(result, _options, theme) {
			return renderToolResult(result, theme);
		},
	});

	pi.registerTool({
		name: "kanban_summary",
		label: "Kanban Summary",
		description: "Return the current kanban board and active task summary.",
		promptSnippet: "Summarize the current project kanban board.",
		promptGuidelines: ["Use this tool before planning work when you need the current board state."],
		parameters: Type.Object({}),
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			const snapshot = loadBoard(ctx.cwd, { migrateLegacy: true });
			syncKanbanUi(ctx, snapshot);
			const summary = joinWithMigrationNotice(snapshot.migrated, renderBoard(snapshot));
			return buildResult({
				action: "summary",
				summary,
				changed: false,
				boardExists: snapshot.exists,
				migrated: snapshot.migrated,
			});
		},
		renderCall(_args, theme) {
			return new Text(theme.fg("toolTitle", theme.bold("kanban_summary")), 0, 0);
		},
		renderResult(result, _options, theme) {
			return renderToolResult(result, theme);
		},
	});
}

function renderToolResult(result: { content: Array<{ type: string; text?: string }>; details?: KanbanToolDetails }, theme: Theme): Text {
	const details = result.details;
	if (details?.summary) {
		return new Text(details.summary, 0, 0);
	}
	const first = result.content[0];
	return new Text(first?.type === "text" ? first.text ?? "" : theme.fg("dim", "No output"), 0, 0);
}

function buildResult(details: KanbanToolDetails) {
	return {
		content: [{ type: "text" as const, text: details.summary }],
		details,
	};
}

function requireId(id: string | undefined, action: string): string {
	if (!id?.trim()) {
		throw new Error(`kanban ${action} requires an id`);
	}
	return id;
}

function parseFilter(filter: string | undefined) {
	if (!filter?.trim()) {
		return {};
	}
	const trimmed = filter.trim();
	if (isTaskStatus(trimmed)) {
		return { status: trimmed };
	}
	if (trimmed.startsWith("lane:")) {
		const lane = trimmed.slice("lane:".length).trim();
		if (!lane) {
			throw new Error("kanban list filter must be <status>, lane:<lane>, or tag:<tag>");
		}
		return { lane };
	}
	if (trimmed.startsWith("tag:")) {
		const tag = trimmed.slice("tag:".length).trim();
		if (!tag) {
			throw new Error("kanban list filter must be <status>, lane:<lane>, or tag:<tag>");
		}
		return { tag };
	}
	throw new Error("kanban list filter must be <status>, lane:<lane>, or tag:<tag>");
}

function joinWithMigrationNotice(migrated: boolean | undefined, summary: string): string {
	return migrated ? `Migrated legacy kanban tasks to the canonical schema.\n${summary}` : summary;
}

function sessionIdFor(ctx: ExtensionContext): string {
	return basename(ctx.sessionManager.getSessionFile() ?? ctx.sessionManager.getLeafId() ?? "interactive");
}
