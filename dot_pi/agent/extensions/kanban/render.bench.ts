import { performance } from "node:perf_hooks";
import { renderPromptSummary } from "./render";
import type { BoardSnapshot, StoredTask } from "./types";

type FocusBuckets = { active: StoredTask[]; ready: StoredTask[] };

function buildSnapshot(taskCount: number): BoardSnapshot {
	const statuses: StoredTask["meta"]["status"][] = ["backlog", "ready", "doing", "review", "blocked", "done"];
	const tasks: StoredTask[] = Array.from({ length: taskCount }, (_, i) => {
		const status = statuses[i % statuses.length];
		return {
			meta: {
				uuid: `uuid-${i}`,
				alias: `T-${String(i + 1).padStart(3, "0")}`,
				title: `Synthetic task ${i + 1}`,
				status,
				priority: (i % 5) + 1,
				tags: [],
				depends_on: [],
				created_at: "2026-01-01T00:00:00Z",
				updated_at: "2026-01-01T00:00:00Z",
				version: 1,
			},
			body: "Benchmark task",
		};
	});

	return {
		exists: true,
		path: "/tmp/.pi/kanban",
		tasks,
		config: {
			wip: {
				doing: 3,
				review: 2,
				blocked: 2,
			},
		},
	};
}

function collectFocusBucketsOld(snapshot: BoardSnapshot): FocusBuckets {
	return {
		active: snapshot.tasks.filter((task) => task.meta.status === "doing" || task.meta.status === "review" || task.meta.status === "blocked"),
		ready: snapshot.tasks.filter((task) => task.meta.status === "ready"),
	};
}

function collectFocusBucketsNew(snapshot: BoardSnapshot): FocusBuckets {
	const active: StoredTask[] = [];
	const ready: StoredTask[] = [];
	for (const task of snapshot.tasks) {
		if (task.meta.status === "doing" || task.meta.status === "review" || task.meta.status === "blocked") {
			active.push(task);
		}
		if (task.meta.status === "ready") {
			ready.push(task);
		}
	}
	return { active, ready };
}

function measure(label: string, fn: () => void, iterations = 2_000): number {
	const start = performance.now();
	for (let i = 0; i < iterations; i += 1) {
		fn();
	}
	const elapsed = performance.now() - start;
	console.log(`${label}: ${elapsed.toFixed(2)} ms`);
	return elapsed;
}

function run(taskCount: number): void {
	const snapshot = buildSnapshot(taskCount);
	console.log(`\n=== ${taskCount.toLocaleString()} tasks ===`);
	measure("old focus buckets (2 filters)", () => collectFocusBucketsOld(snapshot));
	measure("new focus buckets (single scan)", () => collectFocusBucketsNew(snapshot));
	measure("renderPromptSummary (current)", () => renderPromptSummary(snapshot));
}

run(1_000);
run(5_000);
