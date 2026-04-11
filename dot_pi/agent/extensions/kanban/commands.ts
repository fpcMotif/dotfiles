import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { isTaskStatus } from "./schema";
import { renderBoard, renderMutationSummary, renderTaskDetails, renderTaskList } from "./render";
import { blockTask, claimTask, completeTask, createTask, listTasks, loadBoard, moveTask, showTask, unblockTask } from "./store";
import { syncKanbanUi } from "./hooks";
import type { AddTaskInput, ListFilter, TaskStatus } from "./types";

export function registerKanbanCommands(pi: ExtensionAPI): void {
	pi.registerCommand("todo", {
		description:
			"Task management: add <title> [--priority N] [--tag TAG] [--lane LANE] [--due DATE] | list [status|lane:<lane>|tag:<tag>] | show <id> | done <id> | block <id> --reason \"...\" | unblock <id> [--to <status>]",
		handler: async (args, ctx) => {
			const trimmed = (args ?? "").trim();
			if (!trimmed) {
				reportUsageError(ctx, todoUsage());
				return;
			}

			const { subcommand, rest } = splitSubcommand(trimmed);
			try {
				switch (subcommand) {
					case "add": {
						const input = parseAddArgs(rest);
						const result = createTask(ctx.cwd, input, sessionIdFor(ctx));
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					case "list": {
						const filter = parseListFilter(rest);
						const { snapshot, tasks } = listTasks(ctx.cwd, filter, { migrateLegacy: true });
						syncKanbanUi(ctx, snapshot);
						emitMigrationNotice(ctx, snapshot.migrated);
						if (!snapshot.exists || snapshot.tasks.length === 0) {
							emit(ctx, "No tasks found. Use /todo add <title> to create one.", "info");
							return;
						}
						emit(ctx, renderTaskList(tasks), "info");
						return;
					}
					case "show": {
						const taskRef = requireSingleValue(rest, "Usage: /todo show <id>");
						const { snapshot, task } = showTask(ctx.cwd, taskRef, { migrateLegacy: true });
						syncKanbanUi(ctx, snapshot);
						emitMigrationNotice(ctx, snapshot.migrated);
						emit(ctx, renderTaskDetails(task), "info");
						return;
					}
					case "done": {
						const taskRef = requireSingleValue(rest, "Usage: /todo done <id>");
						const result = completeTask(ctx.cwd, taskRef, sessionIdFor(ctx));
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					case "block": {
						const { taskRef, reason } = parseBlockArgs(rest);
						const result = blockTask(ctx.cwd, taskRef, reason, sessionIdFor(ctx));
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					case "unblock": {
						const { taskRef, targetStatus } = parseUnblockArgs(rest);
						const result = unblockTask(ctx.cwd, taskRef, sessionIdFor(ctx), targetStatus);
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					default:
						throw new Error(todoUsage());
				}
			} catch (error) {
				const message = formatError(error);
				emit(ctx, message, "error");
				if (!ctx.hasUI) {
					process.exit(1);
				}
			}
		},
	});

	pi.registerCommand("kanban", {
		description: "Kanban board: board | claim <id> | move <id> <status>",
		handler: async (args, ctx) => {
			const trimmed = (args ?? "").trim();
			if (!trimmed) {
				reportUsageError(ctx, kanbanUsage());
				return;
			}

			const { subcommand, rest } = splitSubcommand(trimmed);
			try {
				switch (subcommand) {
					case "board": {
						const snapshot = loadBoard(ctx.cwd, { migrateLegacy: true });
						syncKanbanUi(ctx, snapshot);
						emitMigrationNotice(ctx, snapshot.migrated);
						emit(ctx, renderBoard(snapshot), "info");
						return;
					}
					case "claim": {
						const taskRef = requireSingleValue(rest, "Usage: /kanban claim <id>");
						const result = claimTask(ctx.cwd, taskRef, sessionIdFor(ctx));
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					case "move": {
						const [taskRef, nextStatus] = splitRequiredPair(rest, "Usage: /kanban move <id> <status>");
						if (!isTaskStatus(nextStatus)) {
							throw new Error(`Invalid status \"${nextStatus}\". Valid: backlog, ready, doing, review, done, blocked`);
						}
						const result = moveTask(ctx.cwd, taskRef, nextStatus, sessionIdFor(ctx));
						syncKanbanUi(ctx, result.snapshot);
						emit(ctx, renderMutationSummary(result), "success");
						return;
					}
					default:
						throw new Error(kanbanUsage());
				}
			} catch (error) {
				const message = formatError(error);
				emit(ctx, message, "error");
				if (!ctx.hasUI) {
					process.exit(1);
				}
			}
		},
	});
}

function reportUsageError(ctx: ExtensionContext, message: string): void {
	emit(ctx, message, "error");
	if (!ctx.hasUI) {
		process.exit(1);
	}
}

function emit(ctx: ExtensionContext, message: string, level: "info" | "success" | "warning" | "error"): void {
	if (ctx.hasUI) {
		ctx.ui.notify(message, level);
		return;
	}
	const stream = level === "error" ? process.stderr : process.stdout;
	stream.write(message.endsWith("\n") ? message : `${message}\n`);
}

function emitMigrationNotice(ctx: ExtensionContext, migrated: boolean): void {
	if (migrated) {
		emit(ctx, "Migrated legacy kanban tasks to the canonical schema.", "info");
	}
}

function sessionIdFor(ctx: ExtensionContext): string {
	return basename(ctx.sessionManager.getSessionFile() ?? ctx.sessionManager.getLeafId() ?? "interactive");
}

function splitSubcommand(input: string): { subcommand: string; rest: string } {
	const firstSpace = input.indexOf(" ");
	if (firstSpace === -1) {
		return { subcommand: input.toLowerCase(), rest: "" };
	}
	return {
		subcommand: input.slice(0, firstSpace).toLowerCase(),
		rest: input.slice(firstSpace + 1).trim(),
	};
}

function parseAddArgs(input: string): AddTaskInput {
	const tokens = splitArgs(input);
	const titleParts: string[] = [];
	const tags: string[] = [];
	let priority: number | undefined;
	let lane: string | undefined;
	let due_at: string | undefined;

	for (let index = 0; index < tokens.length; index += 1) {
		const token = tokens[index];
		switch (token) {
			case "--priority":
			case "-p": {
				const value = tokens[index + 1];
				if (!value) {
					throw new Error("Usage: /todo add <title> [--priority N] [--tag TAG] [--lane LANE] [--due DATE]");
				}
				priority = parseInteger(value, "priority");
				index += 1;
				break;
			}
			case "--tag":
			case "-t": {
				const value = tokens[index + 1];
				if (!value) {
					throw new Error("--tag requires a value");
				}
				tags.push(stripQuotes(value));
				index += 1;
				break;
			}
			case "--lane": {
				const value = tokens[index + 1];
				if (!value) {
					throw new Error("--lane requires a value");
				}
				lane = stripQuotes(value);
				index += 1;
				break;
			}
			case "--due": {
				const value = tokens[index + 1];
				if (!value) {
					throw new Error("--due requires a value");
				}
				due_at = stripQuotes(value);
				index += 1;
				break;
			}
			default: {
				if (token.startsWith("-")) {
					throw new Error(`Unknown flag: ${token}`);
				}
				titleParts.push(stripQuotes(token));
			}
		}
	}

	const title = titleParts.join(" ").trim();
	if (!title) {
		throw new Error("Usage: /todo add <title> [--priority N] [--tag TAG] [--lane LANE] [--due DATE]");
	}

	return { title, priority, tags, lane, due_at };
}

function parseListFilter(input: string): ListFilter {
	const tokens = splitArgs(input.trim());
	if (tokens.length === 0) {
		return {};
	}
	if (tokens.length !== 1) {
		throw new Error("Usage: /todo list [<status>|lane:<lane>|tag:<tag>]");
	}
	const filter = tokens[0].trim();
	if (isTaskStatus(filter)) {
		return { status: filter };
	}
	if (filter.startsWith("lane:")) {
		const lane = stripQuotes(filter.slice("lane:".length).trim());
		if (!lane) {
			throw new Error("Usage: /todo list [<status>|lane:<lane>|tag:<tag>]");
		}
		return { lane };
	}
	if (filter.startsWith("tag:")) {
		const tag = stripQuotes(filter.slice("tag:".length).trim());
		if (!tag) {
			throw new Error("Usage: /todo list [<status>|lane:<lane>|tag:<tag>]");
		}
		return { tag };
	}
	throw new Error("Usage: /todo list [<status>|lane:<lane>|tag:<tag>]");
}

function parseBlockArgs(input: string): { taskRef: string; reason: string } {
	const tokens = splitArgs(input);
	const taskRef = stripQuotes(tokens[0] ?? "");
	if (!taskRef) {
		throw new Error("Usage: /todo block <id> --reason \"...\"");
	}
	let reason: string | undefined;
	for (let index = 1; index < tokens.length; index += 1) {
		const token = tokens[index];
		if (token === "--reason") {
			const value = tokens[index + 1];
			if (!value) {
				throw new Error("--reason requires a value");
			}
			reason = stripQuotes(value);
			index += 1;
			continue;
		}
		throw new Error(`Unknown block argument: ${token}`);
	}
	if (!reason) {
		throw new Error("Usage: /todo block <id> --reason \"...\"");
	}
	return { taskRef, reason };
}

function parseUnblockArgs(input: string): { taskRef: string; targetStatus?: TaskStatus } {
	const tokens = splitArgs(input);
	const taskRef = stripQuotes(tokens[0] ?? "");
	if (!taskRef) {
		throw new Error("Usage: /todo unblock <id> [--to <backlog|ready|doing|review>]");
	}
	if (tokens.length === 1) {
		return { taskRef };
	}
	if (tokens.length === 3 && tokens[1] === "--to") {
		const candidate = stripQuotes(tokens[2]);
		if (!isTaskStatus(candidate) || candidate === "blocked" || candidate === "done") {
			throw new Error("Unblock target must be backlog, ready, doing, or review");
		}
		return { taskRef, targetStatus: candidate };
	}
	throw new Error("Usage: /todo unblock <id> [--to <backlog|ready|doing|review>]");
}

function splitRequiredPair(input: string, usage: string): [string, string] {
	const tokens = splitArgs(input);
	if (tokens.length !== 2) {
		throw new Error(usage);
	}
	return [stripQuotes(tokens[0]), stripQuotes(tokens[1])];
}

function requireSingleValue(input: string, usage: string): string {
	const tokens = splitArgs(input);
	if (tokens.length !== 1) {
		throw new Error(usage);
	}
	return stripQuotes(tokens[0]);
}

function splitArgs(input: string): string[] {
	const tokens: string[] = [];
	let current = "";
	let quote: '"' | "'" | null = null;

	for (const character of input) {
		if (quote) {
			if (character === quote) {
				quote = null;
			} else {
				current += character;
			}
			continue;
		}

		if (character === '"' || character === "'") {
			quote = character;
			continue;
		}
		if (/\s/.test(character)) {
			if (current.length > 0) {
				tokens.push(current);
				current = "";
			}
			continue;
		}
		current += character;
	}

	if (quote) {
		throw new Error("Unmatched quote in arguments");
	}
	if (current.length > 0) {
		tokens.push(current);
	}
	return tokens;
}

function stripQuotes(value: string): string {
	return value.replace(/^(["'])(.*)\1$/, "$2").trim();
}

function parseInteger(raw: string, field: string): number {
	if (!/^\d+$/.test(raw)) {
		throw new Error(`${field} must be an integer`);
	}
	return Number(raw);
}

function todoUsage(): string {
	return "Usage: /todo add|list|show|done|block|unblock [--to <status>] ...";
}

function kanbanUsage(): string {
	return "Usage: /kanban board | claim <id> | move <id> <status>";
}

function formatError(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}
