import type { BoardConfig, StoredTask, TaskMeta, TaskStatus, WipStatus } from "./types";
import { STATUS_ORDER, TASK_STATUSES, WIP_STATUSES } from "./types";

export interface LegacyTaskMeta {
	id: string;
	title: string;
	status: TaskStatus;
	priority: number;
	created: string;
	updated: string;
	assignee: string | null;
	tags: string[];
	blocked_by: string[];
}

export interface LegacyTaskFile {
	meta: LegacyTaskMeta;
	body: string;
}

const FRONTMATTER_REGEX = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/;
const TASK_STATUS_SET = new Set<string>(TASK_STATUSES);
const WIP_STATUS_SET = new Set<string>(WIP_STATUSES);
const STATUS_INDEX = new Map<string, number>(STATUS_ORDER.map((status, index) => [status, index]));
const SINGLE_LINE_LIMITS = {
	title: 200,
	lane: 80,
	due_at: 80,
	blocked_reason: 240,
	claimed_by_session: 240,
	tag: 64,
	dependency: 80,
} as const;

export const DEFAULT_CONFIG: BoardConfig = {
	wip: { doing: 3, review: 2 },
};

export const DEFAULT_TASK_BODY = "## Notes\n";

export function isTaskStatus(value: unknown): value is TaskStatus {
	return typeof value === "string" && TASK_STATUS_SET.has(value);
}

export function isWipStatus(value: unknown): value is WipStatus {
	return typeof value === "string" && WIP_STATUS_SET.has(value);
}

export function parseBoardConfig(content: string, source: string): BoardConfig {
	const raw = parseJson(content, source);
	if (!isRecord(raw)) {
		throw new Error(`${source}: kanban config must be a JSON object`);
	}

	const wip: Partial<Record<WipStatus, number>> = { ...DEFAULT_CONFIG.wip };
	const rawWip = raw.wip;
	if (rawWip !== undefined) {
		if (!isRecord(rawWip)) {
			throw new Error(`${source}: wip must be an object`);
		}
		for (const [key, value] of Object.entries(rawWip)) {
			if (!isWipStatus(key)) {
				throw new Error(`${source}: unsupported WIP lane "${key}"`);
			}
			if (!Number.isInteger(value) || value < 1) {
				throw new Error(`${source}: WIP limit for "${key}" must be a positive integer`);
			}
			wip[key] = value;
		}
	}

	return { wip };
}

export function parseTaskFile(content: string, source: string): { meta: TaskMeta; body: string } {
	const parsed = parseFrontmatter(content, source);
	return {
		meta: parseTaskMeta(parsed.meta, source),
		body: normalizeBody(parsed.body),
	};
}

export function tryParseLegacyTaskFile(content: string, source: string): LegacyTaskFile | null {
	const parsed = parseFrontmatter(content, source);
	if (!isLegacyTaskMeta(parsed.meta)) {
		return null;
	}
	return {
		meta: parseLegacyTaskMeta(parsed.meta, source),
		body: normalizeBody(parsed.body),
	};
}

export function serializeTaskFile(meta: TaskMeta, body: string): string {
	const normalizedBody = normalizeBody(body);
	return `---\n${JSON.stringify(meta, null, 2)}\n---\n${normalizedBody}\n`;
}

export function validateTaskForWrite(meta: TaskMeta, body: string, source: string): { meta: TaskMeta; body: string } {
	return parseTaskFile(serializeTaskFile(meta, body), source);
}

export function taskFilename(alias: string, title: string): string {
	return `${alias.toLowerCase()}-${slugify(title)}.md`;
}

export function slugify(input: string): string {
	const slug = input
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 60);
	return slug || "task";
}

export function formatAlias(number: number): string {
	return `T-${String(number).padStart(3, "0")}`;
}

export function aliasNumber(alias: string): number {
	const match = /^T-(\d+)$/i.exec(alias.trim());
	return match ? Number(match[1]) : Number.NaN;
}

export function normalizeTaskReference(raw: string): string {
	const value = raw.trim().replace(/^#/, "");
	if (/^T-\d+$/i.test(value)) {
		return `T-${value.slice(2).padStart(3, "0")}`;
	}
	if (/^\d+$/.test(value)) {
		return formatAlias(Number(value));
	}
	return value;
}

export function compareTasks(left: StoredTask, right: StoredTask): number {
	const statusDelta = (STATUS_INDEX.get(left.meta.status) ?? 999) - (STATUS_INDEX.get(right.meta.status) ?? 999);
	if (statusDelta !== 0) {
		return statusDelta;
	}
	const priorityDelta = left.meta.priority - right.meta.priority;
	if (priorityDelta !== 0) {
		return priorityDelta;
	}
	const leftAlias = aliasNumber(left.meta.alias);
	const rightAlias = aliasNumber(right.meta.alias);
	if (!Number.isNaN(leftAlias) && !Number.isNaN(rightAlias) && leftAlias !== rightAlias) {
		return leftAlias - rightAlias;
	}
	return left.meta.created_at.localeCompare(right.meta.created_at);
}

function parseFrontmatter(content: string, source: string): { meta: unknown; body: string } {
	const match = FRONTMATTER_REGEX.exec(content);
	if (!match) {
		throw new Error(`${source}: expected JSON front matter delimited by ---`);
	}
	return {
		meta: parseJson(match[1], source),
		body: match[2],
	};
}

function parseTaskMeta(raw: unknown, source: string): TaskMeta {
	if (!isRecord(raw)) {
		throw new Error(`${source}: task metadata must be an object`);
	}

	const uuid = readRequiredString(raw, "uuid", source);
	const alias = normalizeCanonicalAlias(readRequiredString(raw, "alias", source), source);
	const title = readInlineString(raw.title, source, "title", SINGLE_LINE_LIMITS.title);
	const status = readStatus(raw.status, source);
	const priority = readPriority(raw.priority, source, "priority");
	const tags = readInlineStringArray(raw.tags, source, "tags", SINGLE_LINE_LIMITS.tag);
	const depends_on = readInlineStringArray(raw.depends_on, source, "depends_on", SINGLE_LINE_LIMITS.dependency);
	const created_at = readRequiredString(raw, "created_at", source);
	const updated_at = readRequiredString(raw, "updated_at", source);
	const started_at = readOptionalInlineString(raw.started_at, source, "started_at", SINGLE_LINE_LIMITS.due_at);
	const finished_at = readOptionalInlineString(raw.finished_at, source, "finished_at", SINGLE_LINE_LIMITS.due_at);
	const due_at = readOptionalInlineString(raw.due_at, source, "due_at", SINGLE_LINE_LIMITS.due_at);
	const blocked_reason = readOptionalInlineString(
		raw.blocked_reason,
		source,
		"blocked_reason",
		SINGLE_LINE_LIMITS.blocked_reason,
	);
	const lane = readOptionalInlineString(raw.lane, source, "lane", SINGLE_LINE_LIMITS.lane);
	const claimed_by_session = readOptionalInlineString(
		raw.claimed_by_session,
		source,
		"claimed_by_session",
		SINGLE_LINE_LIMITS.claimed_by_session,
	);
	const version = readPositiveInteger(raw.version, source, "version");

	return {
		uuid,
		alias,
		title,
		status,
		priority,
		tags: dedupeStrings(tags),
		lane,
		created_at,
		updated_at,
		started_at,
		finished_at,
		due_at,
		blocked_reason,
		depends_on: dedupeStrings(depends_on),
		claimed_by_session,
		version,
	};
}

function isLegacyTaskMeta(raw: unknown): raw is Record<string, unknown> {
	return isRecord(raw) && !("uuid" in raw) && typeof raw.id === "string" && typeof raw.title === "string";
}

function parseLegacyTaskMeta(raw: Record<string, unknown>, source: string): LegacyTaskMeta {
	const id = readRequiredString(raw, "id", source);
	const title = readInlineString(raw.title, source, "title", SINGLE_LINE_LIMITS.title);
	const status = raw.status === undefined ? "backlog" : readStatus(raw.status, source);
	const priority = raw.priority === undefined ? 5 : readPriority(raw.priority, source, "priority");
	const created = raw.created === undefined ? new Date(0).toISOString() : readRequiredString(raw, "created", source);
	const updated = raw.updated === undefined ? created : readRequiredString(raw, "updated", source);
	const assignee = readOptionalInlineString(raw.assignee, source, "assignee", SINGLE_LINE_LIMITS.claimed_by_session) ?? null;
	const tags = readInlineStringArray(raw.tags ?? [], source, "tags", SINGLE_LINE_LIMITS.tag);
	const blocked_by = readInlineStringArray(raw.blocked_by ?? [], source, "blocked_by", SINGLE_LINE_LIMITS.dependency);

	return {
		id,
		title,
		status,
		priority,
		created,
		updated,
		assignee,
		tags: dedupeStrings(tags),
		blocked_by: dedupeStrings(blocked_by),
	};
}

function normalizeBody(body: string): string {
	const trimmed = body.replace(/\s+$/, "");
	return trimmed.length > 0 ? trimmed : DEFAULT_TASK_BODY.trimEnd();
}

function normalizeCanonicalAlias(alias: string, source: string): string {
	const normalized = normalizeTaskReference(alias);
	if (!/^T-\d+$/.test(normalized)) {
		throw new Error(`${source}: alias must look like T-001`);
	}
	return normalized;
}

function readStatus(value: unknown, source: string): TaskStatus {
	if (!isTaskStatus(value)) {
		throw new Error(`${source}: invalid task status "${String(value)}"`);
	}
	return value;
}

function readPriority(value: unknown, source: string, field: string): number {
	if (!Number.isInteger(value) || value < 1 || value > 9) {
		throw new Error(`${source}: ${field} must be an integer between 1 and 9`);
	}
	return value;
}

function readPositiveInteger(value: unknown, source: string, field: string): number {
	if (!Number.isInteger(value) || value < 1) {
		throw new Error(`${source}: ${field} must be a positive integer`);
	}
	return value;
}

function readRequiredString(record: Record<string, unknown>, field: string, source: string): string {
	return readString(record[field], source, field);
}

function readOptionalInlineString(value: unknown, source: string, field: string, maxLength: number): string | undefined {
	if (value === undefined || value === null) {
		return undefined;
	}
	return readInlineString(value, source, field, maxLength);
}

function readInlineString(value: unknown, source: string, field: string, maxLength: number): string {
	const normalized = readString(value, source, field);
	if (/\r|\n/.test(normalized)) {
		throw new Error(`${source}: ${field} must stay on one line`);
	}
	if (normalized.length > maxLength) {
		throw new Error(`${source}: ${field} must be at most ${maxLength} characters`);
	}
	return normalized;
}

function readString(value: unknown, source: string, field: string): string {
	if (typeof value !== "string" || value.trim().length === 0) {
		throw new Error(`${source}: ${field} must be a non-empty string`);
	}
	return value.trim();
}

function readInlineStringArray(value: unknown, source: string, field: string, maxLength: number): string[] {
	if (!Array.isArray(value)) {
		throw new Error(`${source}: ${field} must be an array of strings`);
	}
	return value.map((entry, index) => readInlineString(entry, source, `${field}[${index}]`, maxLength));
}

function dedupeStrings(values: string[]): string[] {
	return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function parseJson(content: string, source: string): unknown {
	try {
		return JSON.parse(content);
	} catch (error) {
		const reason = error instanceof Error ? error.message : String(error);
		throw new Error(`${source}: invalid JSON (${reason})`);
	}
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
