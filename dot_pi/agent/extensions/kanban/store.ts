import { randomUUID } from "node:crypto";
import {
	appendFileSync,
	existsSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	rmSync,
	statSync,
	unlinkSync,
	writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { migrateLegacyBoard } from "./migrate";
import {
	DEFAULT_CONFIG,
	DEFAULT_TASK_BODY,
	aliasNumber,
	compareTasks,
	formatAlias,
	isTaskStatus,
	normalizeTaskReference,
	parseBoardConfig,
	parseTaskFile,
	serializeTaskFile,
	taskFilename,
	validateTaskForWrite,
} from "./schema";
import type {
	AddTaskInput,
	BoardConfig,
	BoardPaths,
	BoardSnapshot,
	ListFilter,
	MutationResult,
	StoredTask,
	TaskEvent,
	TaskEventType,
	TaskMeta,
	TaskStatus,
} from "./types";

const ACTIVE_STATUSES = new Set<TaskStatus>(["doing", "review", "blocked"]);
const MUTABLE_STATUSES = new Set<TaskStatus>(["backlog", "ready", "doing", "review", "blocked", "done"]);
const BOARD_LOCK_FILENAME = ".kanban.lock";
const BOARD_LOCK_TIMEOUT_MS = 3000;
const MAX_LOCK_AGE_MS = 3_600_000;
const LOCK_HEARTBEAT_MS = 15_000;
const MALFORMED_LOCK_GRACE_MS = 500;
const LOCK_WAIT = new Int32Array(new SharedArrayBuffer(4));

export function getBoardPaths(cwd: string): BoardPaths {
	const rootDir = join(cwd, ".pi");
	const todosDir = join(rootDir, "todos");
	return {
		rootDir,
		todosDir,
		configPath: join(rootDir, "kanban.json"),
		eventsPath: join(todosDir, ".events.ndjson"),
	};
}

export function loadBoard(cwd: string, options: { migrateLegacy?: boolean } = {}): BoardSnapshot {
	const paths = getBoardPaths(cwd);
	if (options.migrateLegacy && existsSync(paths.todosDir)) {
		return withBoardLock(paths, () => readBoardSnapshot(paths, true));
	}
	return readBoardSnapshot(paths, options.migrateLegacy ?? false);
}

export function listTasks(
	cwd: string,
	filter: ListFilter = {},
	options: { migrateLegacy?: boolean } = {},
): { snapshot: BoardSnapshot; tasks: StoredTask[] } {
	const snapshot = loadBoard(cwd, options);
	return {
		snapshot,
		tasks: snapshot.tasks.filter((task) => matchesFilter(task, filter)),
	};
}

export function showTask(
	cwd: string,
	taskRef: string,
	options: { migrateLegacy?: boolean } = {},
): { snapshot: BoardSnapshot; task: StoredTask } {
	const snapshot = loadBoard(cwd, options);
	if (!snapshot.exists) {
		throw new Error("No kanban board found in this project. Use /todo add <title> to create one.");
	}
	const task = findTask(snapshot.tasks, taskRef);
	if (!task) {
		throw new Error(`Task ${taskRef} not found`);
	}
	return { snapshot, task };
}

export function assertTaskVersion(cwd: string, taskRef: string, expectedVersion: number): void {
	const { task } = showTask(cwd, taskRef);
	assertExpectedVersion(task.path, expectedVersion);
}

export function createTask(cwd: string, input: AddTaskInput, sessionId?: string): MutationResult {
	if (!input.title.trim()) {
		throw new Error("Task title is required");
	}

	const paths = getBoardPaths(cwd);
	ensureStorage(paths);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const alias = formatAlias(nextAliasNumber(snapshot.tasks));
		const now = new Date().toISOString();
		const meta: TaskMeta = {
			uuid: randomUUID(),
			alias,
			title: input.title.trim(),
			status: "backlog",
			priority: normalizePriority(input.priority),
			tags: dedupeStrings(input.tags ?? []),
			created_at: now,
			updated_at: now,
			due_at: normalizeOptionalString(input.due_at),
			lane: normalizeOptionalString(input.lane),
			depends_on: dedupeStrings(input.depends_on ?? []),
			version: 1,
		};
		const body = normalizeBody(input.body);
		const path = join(paths.todosDir, taskFilename(meta.alias, meta.title));
		const validated = validateTaskForWrite(meta, body, path);
		writeFileSync(path, serializeTaskFile(validated.meta, validated.body), "utf-8");
		const event = createEvent("created", validated.meta, {
			session: sessionId,
			to_status: validated.meta.status,
			details: {
				priority: validated.meta.priority,
				lane: validated.meta.lane,
				tags: validated.meta.tags,
				due_at: validated.meta.due_at,
			},
		});
		try {
			appendEvent(paths, event);
		} catch (error) {
			if (existsSync(path)) {
				unlinkSync(path);
			}
			throw error;
		}
		const nextSnapshot = readBoardSnapshot(paths, false);
		const task = requireTask(nextSnapshot.tasks, validated.meta.uuid);
		return {
			message: `Created ${validated.meta.alias}: ${validated.meta.title} (backlog, P${validated.meta.priority})`,
			task,
			snapshot: nextSnapshot,
			event,
			changed: true,
		};
	});
}

export function claimTask(cwd: string, taskRef: string, sessionId?: string): MutationResult {
	const paths = getBoardPaths(cwd);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const task = requireExistingTask(snapshot, taskRef);
		if (sessionId && task.meta.status === "doing" && task.meta.claimed_by_session === sessionId) {
			return noChangeResult(snapshot, task, `${task.meta.alias} is already claimed by this session`);
		}
		if (task.meta.status !== "ready") {
			throw new Error(`Claim only works for ready tasks; ${task.meta.alias} is currently ${task.meta.status}`);
		}
		assertWipCapacity(snapshot, "doing", task.meta.uuid);
		const now = new Date().toISOString();
		const nextMeta: TaskMeta = {
			...task.meta,
			status: "doing",
			updated_at: now,
			started_at: task.meta.started_at ?? now,
			finished_at: undefined,
			blocked_reason: undefined,
			claimed_by_session: sessionId,
			version: task.meta.version + 1,
		};
		return persistTaskUpdate(paths, nextMeta, task, task.body, {
			type: "claimed",
			session: sessionId,
			from_status: task.meta.status,
			to_status: nextMeta.status,
		}, `${task.meta.alias} "${task.meta.title}" ready → doing`);
	});
}

export function moveTask(cwd: string, taskRef: string, targetStatus: TaskStatus, sessionId?: string): MutationResult {
	if (!MUTABLE_STATUSES.has(targetStatus)) {
		throw new Error(`Unsupported status: ${targetStatus}`);
	}
	if (targetStatus === "blocked") {
		throw new Error("Use /todo block <id> --reason \"...\" to move a task into blocked");
	}
	const paths = getBoardPaths(cwd);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const task = requireExistingTask(snapshot, taskRef);
		if (task.meta.status === "blocked" && targetStatus !== "blocked") {
			throw new Error(`Use /todo unblock ${task.meta.alias} to move a blocked task back into flow`);
		}
		if (task.meta.status === "ready" && targetStatus === "doing") {
			throw new Error(`Use /kanban claim ${task.meta.alias} to move a ready task into doing`);
		}
		if (task.meta.status === targetStatus) {
			return noChangeResult(snapshot, task, `${task.meta.alias} is already ${targetStatus}`);
		}
		if (targetStatus === "done") {
			const now = new Date().toISOString();
			const nextMeta: TaskMeta = {
				...task.meta,
				status: "done",
				updated_at: now,
				finished_at: now,
				blocked_reason: undefined,
				claimed_by_session: undefined,
				version: task.meta.version + 1,
			};
			return persistTaskUpdate(paths, nextMeta, task, task.body, {
				type: "done",
				session: sessionId,
				from_status: task.meta.status,
				to_status: nextMeta.status,
			}, `${task.meta.alias} "${task.meta.title}" → done`);
		}
		if (targetStatus === "doing" || targetStatus === "review") {
			assertWipCapacity(snapshot, targetStatus, task.meta.uuid);
		}
		const now = new Date().toISOString();
		const nextMeta: TaskMeta = {
			...task.meta,
			status: targetStatus,
			updated_at: now,
			started_at: ACTIVE_STATUSES.has(targetStatus) ? task.meta.started_at ?? now : task.meta.started_at,
			finished_at: undefined,
			blocked_reason: undefined,
			claimed_by_session: updateClaimedSession(task.meta, targetStatus, sessionId),
			version: task.meta.version + 1,
		};
		return persistTaskUpdate(paths, nextMeta, task, task.body, {
			type: "moved",
			session: sessionId,
			from_status: task.meta.status,
			to_status: targetStatus,
		}, `${task.meta.alias} "${task.meta.title}" ${task.meta.status} → ${targetStatus}`);
	});
}

export function blockTask(cwd: string, taskRef: string, reason: string, sessionId?: string): MutationResult {
	const trimmedReason = reason.trim();
	if (!trimmedReason) {
		throw new Error("Blocking a task requires a non-empty reason");
	}
	const paths = getBoardPaths(cwd);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const task = requireExistingTask(snapshot, taskRef);
		if (task.meta.status === "done") {
			throw new Error(`Cannot block ${task.meta.alias}; it is already done`);
		}
		const now = new Date().toISOString();
		const nextMeta: TaskMeta = {
			...task.meta,
			status: "blocked",
			updated_at: now,
			started_at: ACTIVE_STATUSES.has(task.meta.status) ? task.meta.started_at ?? now : task.meta.started_at,
			finished_at: undefined,
			blocked_reason: trimmedReason,
			claimed_by_session: ACTIVE_STATUSES.has(task.meta.status)
				? task.meta.claimed_by_session ?? sessionId
				: task.meta.claimed_by_session,
			version: task.meta.version + 1,
		};
		const eventType: TaskEventType = task.meta.status === "blocked" ? "edited" : "blocked";
		const message =
			task.meta.status === "blocked"
				? `Updated block on ${task.meta.alias}: ${trimmedReason}`
				: `${task.meta.alias} "${task.meta.title}" ${task.meta.status} → blocked`;
		return persistTaskUpdate(paths, nextMeta, task, task.body, {
			type: eventType,
			session: sessionId,
			from_status: task.meta.status,
			to_status: nextMeta.status,
			details: { reason: trimmedReason },
		}, message);
	});
}

export function unblockTask(
	cwd: string,
	taskRef: string,
	sessionId?: string,
	requestedStatus?: TaskStatus,
): MutationResult {
	const paths = getBoardPaths(cwd);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const task = requireExistingTask(snapshot, taskRef);
		if (task.meta.status !== "blocked") {
			throw new Error(`${task.meta.alias} is not blocked`);
		}
		const targetStatus = resolveUnblockStatus(task, snapshot.events, requestedStatus);
		if (targetStatus === "doing" || targetStatus === "review") {
			assertWipCapacity(snapshot, targetStatus, task.meta.uuid);
		}
		const now = new Date().toISOString();
		const nextMeta: TaskMeta = {
			...task.meta,
			status: targetStatus,
			updated_at: now,
			started_at: ACTIVE_STATUSES.has(targetStatus) ? task.meta.started_at ?? now : task.meta.started_at,
			blocked_reason: undefined,
			finished_at: targetStatus === "done" ? now : undefined,
			claimed_by_session: updateClaimedSession(task.meta, targetStatus, sessionId),
			version: task.meta.version + 1,
		};
		return persistTaskUpdate(paths, nextMeta, task, task.body, {
			type: "unblocked",
			session: sessionId,
			from_status: task.meta.status,
			to_status: targetStatus,
		}, `${task.meta.alias} unblocked → ${targetStatus}`);
	});
}

export function completeTask(cwd: string, taskRef: string, sessionId?: string): MutationResult {
	const paths = getBoardPaths(cwd);
	return withBoardLock(paths, () => {
		const snapshot = readBoardSnapshot(paths, true);
		const task = requireExistingTask(snapshot, taskRef);
		if (task.meta.status === "done") {
			return noChangeResult(snapshot, task, `${task.meta.alias} is already done`);
		}
		const now = new Date().toISOString();
		const nextMeta: TaskMeta = {
			...task.meta,
			status: "done",
			updated_at: now,
			finished_at: now,
			blocked_reason: undefined,
			claimed_by_session: undefined,
			version: task.meta.version + 1,
		};
		return persistTaskUpdate(paths, nextMeta, task, task.body, {
			type: "done",
			session: sessionId,
			from_status: task.meta.status,
			to_status: nextMeta.status,
		}, `${task.meta.alias} "${task.meta.title}" → done`);
	});
}

export function findTask(tasks: StoredTask[], taskRef: string): StoredTask | undefined {
	const normalized = normalizeTaskReference(taskRef);
	const trimmed = taskRef.trim();
	return tasks.find((task) => task.meta.alias === normalized || task.meta.uuid === trimmed);
}

function readBoardSnapshot(paths: BoardPaths, migrateLegacy: boolean): BoardSnapshot {
	const migrated = migrateLegacy ? migrateLegacyBoard(paths) : false;
	return {
		exists: existsSync(paths.todosDir),
		migrated,
		config: loadConfig(paths.configPath),
		tasks: readTasks(paths),
		events: readEvents(paths),
	};
}

function persistTaskUpdate(
	paths: BoardPaths,
	nextMeta: TaskMeta,
	currentTask: StoredTask,
	nextBody: string,
	eventInit: {
		type: TaskEventType;
		session?: string;
		from_status?: TaskStatus;
		to_status?: TaskStatus;
		details?: Record<string, unknown>;
	},
	message: string,
): MutationResult {
	const path = join(paths.todosDir, taskFilename(nextMeta.alias, nextMeta.title));
	const validated = validateTaskForWrite(nextMeta, nextBody, path);
	const previousContent = readFileSync(currentTask.path, "utf-8");
	assertExpectedVersion(currentTask.path, currentTask.meta.version);
	writeFileSync(path, serializeTaskFile(validated.meta, validated.body), "utf-8");
	const event = createEvent(eventInit.type, validated.meta, {
		session: eventInit.session,
		from_status: eventInit.from_status,
		to_status: eventInit.to_status,
		details: eventInit.details,
	});
	try {
		appendEvent(paths, event);
		if (path !== currentTask.path && existsSync(currentTask.path)) {
			unlinkSync(currentTask.path);
		}
	} catch (error) {
		if (path === currentTask.path) {
			writeFileSync(currentTask.path, previousContent, "utf-8");
		} else {
			if (existsSync(path)) {
				unlinkSync(path);
			}
			if (!existsSync(currentTask.path)) {
				writeFileSync(currentTask.path, previousContent, "utf-8");
			}
		}
		throw error;
	}
	const snapshot = readBoardSnapshot(paths, false);
	const task = requireTask(snapshot.tasks, validated.meta.uuid);
	return {
		message,
		task,
		snapshot,
		event,
		changed: true,
	};
}

function requireExistingTask(snapshot: BoardSnapshot, taskRef: string): StoredTask {
	if (!snapshot.exists) {
		throw new Error("No kanban board found in this project. Use /todo add <title> to create one.");
	}
	const task = findTask(snapshot.tasks, taskRef);
	if (!task) {
		throw new Error(`Task ${taskRef} not found`);
	}
	return task;
}

function requireTask(tasks: StoredTask[], taskRef: string): StoredTask {
	const task = findTask(tasks, taskRef);
	if (!task) {
		throw new Error(`Task ${taskRef} not found after write`);
	}
	return task;
}

function noChangeResult(snapshot: BoardSnapshot, task: StoredTask, message: string): MutationResult {
	return {
		message,
		task,
		snapshot,
		changed: false,
	};
}

function ensureStorage(paths: BoardPaths): void {
	mkdirSync(paths.rootDir, { recursive: true });
	mkdirSync(paths.todosDir, { recursive: true });
}

function loadConfig(configPath: string): BoardConfig {
	if (!existsSync(configPath)) {
		return { ...DEFAULT_CONFIG, wip: { ...DEFAULT_CONFIG.wip } };
	}
	return parseBoardConfig(readFileSync(configPath, "utf-8"), configPath);
}

function readTasks(paths: BoardPaths): StoredTask[] {
	if (!existsSync(paths.todosDir)) {
		return [];
	}
	const tasks: StoredTask[] = [];
	for (const entry of readdirSync(paths.todosDir, { withFileTypes: true })) {
		if (!entry.isFile() || !entry.name.endsWith(".md")) {
			continue;
		}
		const path = join(paths.todosDir, entry.name);
		const { meta, body } = parseTaskFile(readFileSync(path, "utf-8"), path);
		tasks.push({ meta, body, filename: entry.name, path });
	}
	return tasks.sort(compareTasks);
}

function readEvents(paths: BoardPaths): TaskEvent[] {
	if (!existsSync(paths.eventsPath)) {
		return [];
	}
	const content = readFileSync(paths.eventsPath, "utf-8");
	if (!content.trim()) {
		return [];
	}
	return content
		.split("\n")
		.filter(Boolean)
		.map((line, index) => parseEvent(line, `${paths.eventsPath}:${index + 1}`));
}

function parseEvent(line: string, source: string): TaskEvent {
	let raw: unknown;
	try {
		raw = JSON.parse(line);
	} catch (error) {
		const reason = error instanceof Error ? error.message : String(error);
		throw new Error(`${source}: invalid event JSON (${reason})`);
	}
	if (!isRecord(raw)) {
		throw new Error(`${source}: event must be an object`);
	}
	const type = raw.type;
	if (!isEventType(type)) {
		throw new Error(`${source}: invalid event type`);
	}
	const task_uuid = readRequiredString(raw, "task_uuid", source);
	const task_alias = normalizeTaskReference(readRequiredString(raw, "task_alias", source));
	const task_version = readPositiveInteger(raw.task_version, source, "task_version");
	const title = readRequiredString(raw, "title", source);
	const at = readRequiredString(raw, "at", source);
	const from_status = raw.from_status === undefined ? undefined : readEventStatus(raw.from_status, source, "from_status");
	const to_status = raw.to_status === undefined ? undefined : readEventStatus(raw.to_status, source, "to_status");
	const session = raw.session === undefined ? undefined : readRequiredString(raw, "session", source);
	const details = raw.details === undefined ? undefined : readDetails(raw.details, source);
	return {
		type,
		at,
		task_uuid,
		task_alias,
		task_version,
		title,
		session,
		from_status,
		to_status,
		details,
	};
}

function matchesFilter(task: StoredTask, filter: ListFilter): boolean {
	if (filter.status && task.meta.status !== filter.status) {
		return false;
	}
	if (filter.lane && task.meta.lane !== filter.lane) {
		return false;
	}
	if (filter.tag && !task.meta.tags.includes(filter.tag)) {
		return false;
	}
	return true;
}

function nextAliasNumber(tasks: StoredTask[]): number {
	let max = 0;
	for (const task of tasks) {
		const value = aliasNumber(task.meta.alias);
		if (!Number.isNaN(value)) {
			max = Math.max(max, value);
		}
	}
	return max + 1;
}

function assertWipCapacity(snapshot: BoardSnapshot, status: TaskStatus, skipUuid?: string): void {
	const limit = snapshot.config.wip[status as keyof typeof snapshot.config.wip];
	if (!limit) {
		return;
	}
	const current = snapshot.tasks.filter((task) => task.meta.status === status && task.meta.uuid !== skipUuid).length;
	if (current >= limit) {
		throw new Error(`WIP limit reached for ${status} (${current}/${limit}). Move or finish existing work first.`);
	}
}

function resolveUnblockStatus(
	task: StoredTask,
	events: TaskEvent[],
	requestedStatus?: TaskStatus,
): TaskStatus {
	if (requestedStatus !== undefined) {
		if (requestedStatus === "blocked" || requestedStatus === "done") {
			throw new Error("Unblock target must be backlog, ready, doing, or review");
		}
		return requestedStatus;
	}

	for (let index = events.length - 1; index >= 0; index -= 1) {
		const event = events[index];
		if (event.task_uuid !== task.meta.uuid) {
			continue;
		}
		if (event.type === "blocked" && event.from_status && event.from_status !== "blocked") {
			return event.from_status;
		}
		if (event.type === "migrated") {
			const unblockTo = event.details?.unblock_to;
			if (isTaskStatus(unblockTo) && unblockTo !== "blocked" && unblockTo !== "done") {
				return unblockTo;
			}
			if (event.details?.unblock_requires_target === true) {
				throw new Error(
					`Cannot infer an unblock target for migrated task ${task.meta.alias}; use /todo unblock ${task.meta.alias} --to <backlog|ready|doing|review>.`,
				);
			}
		}
	}
	return "ready";
}

function updateClaimedSession(task: TaskMeta, targetStatus: TaskStatus, sessionId?: string): string | undefined {
	if (targetStatus === "backlog" || targetStatus === "ready" || targetStatus === "done") {
		return undefined;
	}
	if (targetStatus === "doing") {
		return sessionId ?? task.claimed_by_session;
	}
	if (targetStatus === "review" || targetStatus === "blocked") {
		return task.claimed_by_session ?? sessionId;
	}
	return task.claimed_by_session;
}

function assertExpectedVersion(path: string, expectedVersion: number): void {
	if (!existsSync(path)) {
		throw new Error(`Stale write refused: ${path} no longer exists on disk`);
	}
	const current = parseTaskFile(readFileSync(path, "utf-8"), path);
	if (current.meta.version !== expectedVersion) {
		throw new Error(
			`Stale write refused for ${current.meta.alias}: expected version ${expectedVersion}, found ${current.meta.version}. Reload and try again.`,
		);
	}
}

function appendEvent(paths: BoardPaths, event: TaskEvent): void {
	appendFileSync(paths.eventsPath, `${JSON.stringify(event)}\n`, "utf-8");
}

function createEvent(
	type: TaskEventType,
	meta: TaskMeta,
	options: {
		session?: string;
		from_status?: TaskStatus;
		to_status?: TaskStatus;
		details?: Record<string, unknown>;
	},
): TaskEvent {
	return {
		type,
		at: new Date().toISOString(),
		task_uuid: meta.uuid,
		task_alias: meta.alias,
		task_version: meta.version,
		title: meta.title,
		session: options.session,
		from_status: options.from_status,
		to_status: options.to_status,
		details: options.details,
	};
}

function normalizePriority(priority?: number): number {
	if (priority === undefined) {
		return 5;
	}
	if (!Number.isInteger(priority) || priority < 1 || priority > 9) {
		throw new Error("Priority must be an integer between 1 and 9");
	}
	return priority;
}

function normalizeBody(body?: string): string {
	const trimmed = (body ?? DEFAULT_TASK_BODY).replace(/\s+$/, "");
	return trimmed.length > 0 ? trimmed : DEFAULT_TASK_BODY.trimEnd();
}

function normalizeOptionalString(value?: string): string | undefined {
	const trimmed = value?.trim();
	return trimmed ? trimmed : undefined;
}

function dedupeStrings(values: string[]): string[] {
	return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function isEventType(value: unknown): value is TaskEventType {
	return (
		value === "created" ||
		value === "moved" ||
		value === "claimed" ||
		value === "blocked" ||
		value === "unblocked" ||
		value === "done" ||
		value === "edited" ||
		value === "migrated"
	);
}

function readEventStatus(value: unknown, source: string, field: string): TaskStatus {
	if (!isTaskStatus(value)) {
		throw new Error(`${source}: ${field} must be a valid task status`);
	}
	return value;
}

function readRequiredString(record: Record<string, unknown>, field: string, source: string): string {
	const value = record[field];
	if (typeof value !== "string" || value.trim().length === 0) {
		throw new Error(`${source}: ${field} must be a non-empty string`);
	}
	return value.trim();
}

function readPositiveInteger(value: unknown, source: string, field: string): number {
	if (!Number.isInteger(value) || value < 1) {
		throw new Error(`${source}: ${field} must be a positive integer`);
	}
	return value;
}

function readDetails(value: unknown, source: string): Record<string, unknown> {
	if (!isRecord(value)) {
		throw new Error(`${source}: details must be an object`);
	}
	return value;
}

function withBoardLock<T>(paths: BoardPaths, action: () => T): T {
	if (!existsSync(paths.rootDir)) {
		mkdirSync(paths.rootDir, { recursive: true });
	}
	const lockPath = join(paths.rootDir, BOARD_LOCK_FILENAME);
	const ownerPath = getLockOwnerPath(lockPath);
	const deadline = Date.now() + BOARD_LOCK_TIMEOUT_MS;
	const token = randomUUID();
	const acquiredAt = new Date().toISOString();
	const lockPayload = () => JSON.stringify({ pid: process.pid, token, acquired_at: acquiredAt, renewed_at: new Date().toISOString() }) + "\n";
	while (true) {
		try {
			mkdirSync(lockPath);
			writeFileSync(ownerPath, lockPayload(), "utf-8");
			const heartbeat = setInterval(() => {
				try {
					writeFileSync(ownerPath, lockPayload(), "utf-8");
				} catch {
					// Another process may have recovered or released the lease.
				}
			}, LOCK_HEARTBEAT_MS);
			if (typeof heartbeat.unref === "function") {
				heartbeat.unref();
			}
			try {
				return action();
			} finally {
				clearInterval(heartbeat);
				releaseBoardLock(lockPath, token);
			}
		} catch (error) {
			if (!isLockContention(error)) {
				throw error;
			}
			if (tryRecoverStaleLock(lockPath)) {
				continue;
			}
			if (Date.now() >= deadline) {
				throw new Error("Kanban board is busy; another session is mutating it. Retry in a moment.");
			}
			sleep(50);
		}
	}
}

function tryRecoverStaleLock(lockPath: string): boolean {
	const info = readLockInfo(lockPath);
	if (info) {
		if (Date.now() - readLockSignalMtime(lockPath) > MAX_LOCK_AGE_MS) {
			releaseBoardLock(lockPath, info.token);
			return true;
		}
		if (isProcessAlive(info.pid)) {
			return false;
		}
		releaseBoardLock(lockPath, info.token);
		return true;
	}
	try {
		const signalMtime = readLockSignalMtime(lockPath);
		if (Date.now() - signalMtime <= MALFORMED_LOCK_GRACE_MS) {
			return false;
		}
		rmSync(lockPath, { recursive: true, force: true });
		return true;
	} catch (error) {
		if (isMissingFile(error)) {
			return false;
		}
		throw error;
	}
}

function getLockOwnerPath(lockPath: string): string {
	return join(lockPath, "owner.json");
}

function readLockSignalMtime(lockPath: string): number {
	try {
		return statSync(getLockOwnerPath(lockPath)).mtimeMs;
	} catch (error) {
		if (!isMalformedOwnerReadError(error)) {
			throw error;
		}
		return statSync(lockPath).mtimeMs;
	}
}

function readLockInfo(lockPath: string): { pid: number; token: string; acquiredAtMs: number } | null {
	let rawContent: string;
	try {
		rawContent = readFileSync(getLockOwnerPath(lockPath), "utf-8");
	} catch (error) {
		if (isMalformedOwnerReadError(error)) {
			return null;
		}
		throw error;
	}
	let raw: { pid?: unknown; token?: unknown; acquired_at?: unknown };
	try {
		raw = JSON.parse(rawContent) as { pid?: unknown; token?: unknown; acquired_at?: unknown };
	} catch {
		return null;
	}
	const acquiredAtMs = typeof raw.acquired_at === "string" ? Date.parse(raw.acquired_at) : Number.NaN;
	if (
		!Number.isSafeInteger(raw.pid) ||
		raw.pid <= 0 ||
		typeof raw.token !== "string" ||
		raw.token.length === 0 ||
		!Number.isFinite(acquiredAtMs)
	) {
		return null;
	}
	return { pid: raw.pid, token: raw.token, acquiredAtMs };
}

function isProcessAlive(pid: number): boolean {
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		if (typeof error === "object" && error !== null && "code" in error) {
			return (error as { code?: string }).code !== "ESRCH";
		}
		return false;
	}
}

function releaseBoardLock(lockPath: string, token: string): void {
	const info = readLockInfo(lockPath);
	if (!info || info.token !== token) {
		return;
	}
	rmSync(lockPath, { recursive: true, force: true });
}

function isLockContention(error: unknown): boolean {
	return typeof error === "object" && error !== null && "code" in error && (error as { code?: string }).code === "EEXIST";
}

function isMalformedOwnerReadError(error: unknown): boolean {
	return (
		typeof error === "object" &&
		error !== null &&
		"code" in error &&
		(["ENOENT", "ENOTDIR", "EISDIR"] as const).includes((error as { code?: string }).code as "ENOENT" | "ENOTDIR" | "EISDIR")
	);
}

function isMissingFile(error: unknown): boolean {
	return typeof error === "object" && error !== null && "code" in error && (error as { code?: string }).code === "ENOENT";
}

function sleep(milliseconds: number): void {
	Atomics.wait(LOCK_WAIT, 0, 0, milliseconds);
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
