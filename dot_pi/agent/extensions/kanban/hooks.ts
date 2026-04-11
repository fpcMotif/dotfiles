import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { renderPromptSummary, renderWidgetLines } from "./render";
import { loadBoard } from "./store";
import type { BoardSnapshot } from "./types";

export function registerKanbanHooks(pi: ExtensionAPI): void {
	const refresh = async (_event: unknown, ctx: ExtensionContext) => {
		if (!ctx.hasUI) {
			return;
		}
		await refreshKanbanUi(ctx);
	};

	pi.on("session_start", refresh);
	pi.on("session_switch", refresh);
	pi.on("session_fork", refresh);
	pi.on("session_tree", refresh);
	pi.on("agent_end", refresh);

	pi.on("before_agent_start", async (_event, ctx) => {
		const { snapshot, error } = safeLoadBoard(ctx);
		if (!snapshot) {
			if (!error) {
				return;
			}
			return {
				systemPromptSuffix: `\n\n## Kanban Warning\nFailed to load the project kanban board: ${error}\n`,
			};
		}
		const summary = renderPromptSummary(snapshot);
		if (!summary) {
			return;
		}
		return {
			systemPromptSuffix: `\n\n${summary}\n`,
		};
	});
}

export function syncKanbanUi(ctx: ExtensionContext, snapshot: BoardSnapshot): void {
	if (!ctx.hasUI) {
		return;
	}
	if (!snapshot.exists || snapshot.tasks.length === 0) {
		ctx.ui.setStatus("kanban", undefined);
		ctx.ui.setWidget("kanban", undefined);
		return;
	}
	ctx.ui.setStatus("kanban", renderFooterStatus(snapshot));
	ctx.ui.setWidget("kanban", renderWidgetLines(snapshot));
}

async function refreshKanbanUi(ctx: ExtensionContext): Promise<void> {
	const { snapshot } = safeLoadBoard(ctx);
	if (snapshot) {
		syncKanbanUi(ctx, snapshot);
	}
}

function safeLoadBoard(ctx: ExtensionContext): { snapshot: BoardSnapshot | null; error: string | null } {
	try {
		return {
			snapshot: loadBoard(ctx.cwd, { migrateLegacy: true }),
			error: null,
		};
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		if (ctx.hasUI) {
			ctx.ui.setStatus("kanban", "kanban error");
			ctx.ui.setWidget("kanban", [`Kanban error: ${message}`]);
		} else {
			process.stderr.write(`Kanban error: ${message}\n`);
		}
		return { snapshot: null, error: message };
	}
}

function renderFooterStatus(snapshot: BoardSnapshot): string {
	const counts = snapshot.tasks.reduce(
		(accumulator, task) => {
			accumulator[task.meta.status] += 1;
			return accumulator;
		},
		{ backlog: 0, ready: 0, doing: 0, review: 0, blocked: 0, done: 0 },
	);
	const parts = [`ready ${counts.ready}`];
	const doingLimit = snapshot.config.wip.doing;
	parts.push(doingLimit ? `doing ${counts.doing}/${doingLimit}` : `doing ${counts.doing}`);
	const reviewLimit = snapshot.config.wip.review;
	parts.push(reviewLimit ? `review ${counts.review}/${reviewLimit}` : `review ${counts.review}`);
	if (counts.blocked > 0) {
		parts.push(`blocked ${counts.blocked}`);
	}
	return parts.join(" | ");
}
