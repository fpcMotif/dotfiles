export const TASK_STATUSES = ["backlog", "ready", "doing", "review", "done", "blocked"] as const;
export type TaskStatus = (typeof TASK_STATUSES)[number];

export const STATUS_ORDER = ["backlog", "ready", "doing", "review", "blocked", "done"] as const;
export const WIP_STATUSES = ["doing", "review"] as const;
export type WipStatus = (typeof WIP_STATUSES)[number];

export interface TaskMeta {
	uuid: string;
	alias: string;
	title: string;
	status: TaskStatus;
	priority: number;
	tags: string[];
	lane?: string;
	created_at: string;
	updated_at: string;
	started_at?: string;
	finished_at?: string;
	due_at?: string;
	blocked_reason?: string;
	depends_on: string[];
	claimed_by_session?: string;
	version: number;
}

export interface StoredTask {
	meta: TaskMeta;
	body: string;
	filename: string;
	path: string;
}

export interface BoardConfig {
	wip: Partial<Record<WipStatus, number>>;
}

export interface BoardPaths {
	rootDir: string;
	todosDir: string;
	configPath: string;
	eventsPath: string;
}

export type TaskEventType = "created" | "moved" | "claimed" | "blocked" | "unblocked" | "done" | "edited" | "migrated";

export interface TaskEvent {
	type: TaskEventType;
	at: string;
	task_uuid: string;
	task_alias: string;
	task_version: number;
	title: string;
	session?: string;
	from_status?: TaskStatus;
	to_status?: TaskStatus;
	details?: Record<string, unknown>;
}

export interface BoardSnapshot {
	exists: boolean;
	migrated: boolean;
	config: BoardConfig;
	tasks: StoredTask[];
	events: TaskEvent[];
}

export interface ListFilter {
	status?: TaskStatus;
	lane?: string;
	tag?: string;
}

export interface AddTaskInput {
	title: string;
	priority?: number;
	tags?: string[];
	lane?: string;
	due_at?: string;
	body?: string;
	depends_on?: string[];
}

export interface MutationResult {
	message: string;
	task: StoredTask;
	snapshot: BoardSnapshot;
	event?: TaskEvent;
	changed: boolean;
}
