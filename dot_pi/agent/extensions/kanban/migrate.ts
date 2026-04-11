import { randomUUID } from "node:crypto";
import { appendFileSync, existsSync, readdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
	formatAlias,
	normalizeTaskReference,
	parseTaskFile,
	serializeTaskFile,
	taskFilename,
	tryParseLegacyTaskFile,
	validateTaskForWrite,
} from "./schema";
import type { BoardPaths, StoredTask, TaskEvent, TaskMeta } from "./types";

interface ExistingTaskFile {
	filename: string;
	path: string;
	task: StoredTask;
}

interface LegacyTaskFileEntry {
	filename: string;
	path: string;
	legacy: NonNullable<ReturnType<typeof tryParseLegacyTaskFile>>;
}

export function migrateLegacyBoard(paths: BoardPaths): boolean {
	if (!existsSync(paths.todosDir)) {
		return false;
	}

	const dirEntries = readdirSync(paths.todosDir, { withFileTypes: true });
	const existing: ExistingTaskFile[] = [];
	const legacy: LegacyTaskFileEntry[] = [];

	for (const entry of dirEntries) {
		if (!entry.isFile() || !entry.name.endsWith(".md")) {
			continue;
		}
		const filePath = join(paths.todosDir, entry.name);
		const content = readFileSync(filePath, "utf-8");
		const canonical = tryReadCanonicalTask(content, filePath, entry.name);
		if (canonical) {
			existing.push(canonical);
			continue;
		}
		const parsedLegacy = tryParseLegacyTaskFile(content, filePath);
		if (!parsedLegacy) {
			throw new Error(`${filePath}: task file is neither canonical nor recognized legacy format`);
		}
		legacy.push({ filename: entry.name, path: filePath, legacy: parsedLegacy });
	}

	if (legacy.length === 0) {
		return false;
	}

	const reservedAliases = new Set(existing.map((entry) => entry.task.meta.alias));
	let nextAliasNumber = maxAliasNumber(reservedAliases) + 1;
	for (const entry of legacy) {
		const alias = allocateAlias(entry.legacy.meta.id, reservedAliases, () => nextAliasNumber++);
		const meta = toCanonicalMeta(entry, alias);
		const nextPath = join(paths.todosDir, taskFilename(meta.alias, meta.title));
		const validated = validateTaskForWrite(meta, entry.legacy.body, nextPath);
		const previousContent = readFileSync(entry.path, "utf-8");
		writeFileSync(nextPath, serializeTaskFile(validated.meta, validated.body), "utf-8");
		const event: TaskEvent = {
			type: "migrated",
			at: new Date().toISOString(),
			task_uuid: validated.meta.uuid,
			task_alias: validated.meta.alias,
			task_version: validated.meta.version,
			title: validated.meta.title,
			from_status: entry.legacy.meta.status,
			to_status: validated.meta.status,
			details: {
				legacy_id: entry.legacy.meta.id,
				legacy_file: entry.filename,
				...(validated.meta.status === "blocked" ? { unblock_requires_target: true } : {}),
			},
		};
		let removedLegacy = false;
		if (nextPath !== entry.path) {
			try {
				unlinkSync(entry.path);
				removedLegacy = true;
			} catch (error) {
				if (existsSync(nextPath)) {
					unlinkSync(nextPath);
				}
				throw error;
			}
		}
		try {
			appendFileSync(paths.eventsPath, `${JSON.stringify(event)}\n`, "utf-8");
		} catch (error) {
			if (nextPath === entry.path) {
				writeFileSync(entry.path, previousContent, "utf-8");
			} else {
				if (existsSync(nextPath)) {
					unlinkSync(nextPath);
				}
				if (removedLegacy) {
					writeFileSync(entry.path, previousContent, "utf-8");
				}
			}
			throw error;
		}
	}

	return true;
}

function tryReadCanonicalTask(content: string, filePath: string, filename: string): ExistingTaskFile | null {
	try {
		const parsed = parseTaskFile(content, filePath);
		return {
			filename,
			path: filePath,
			task: {
				meta: parsed.meta,
				body: parsed.body,
				filename,
				path: filePath,
			},
		};
	} catch {
		return null;
	}
}

function toCanonicalMeta(entry: LegacyTaskFileEntry, alias: string): TaskMeta {
	const { meta } = entry.legacy;
	const started_at = ["doing", "review", "blocked", "done"].includes(meta.status) ? meta.created : undefined;
	const finished_at = meta.status === "done" ? meta.updated : undefined;
	const blocked_reason = meta.status === "blocked" && meta.blocked_by.length > 0 ? meta.blocked_by.join(", ") : undefined;
	return {
		uuid: randomUUID(),
		alias,
		title: meta.title,
		status: meta.status,
		priority: meta.priority,
		tags: meta.tags,
		created_at: meta.created,
		updated_at: meta.updated,
		started_at,
		finished_at,
		blocked_reason,
		depends_on: meta.blocked_by,
		version: 1,
		...(["doing", "review", "blocked"].includes(meta.status) && meta.assignee ? { claimed_by_session: meta.assignee } : {}),
	};
}

function allocateAlias(rawId: string, reservedAliases: Set<string>, nextNumber: () => number): string {
	const normalized = normalizeTaskReference(rawId);
	if (/^T-\d+$/.test(normalized) && !reservedAliases.has(normalized)) {
		reservedAliases.add(normalized);
		return normalized;
	}

	while (true) {
		const alias = formatAlias(nextNumber());
		if (!reservedAliases.has(alias)) {
			reservedAliases.add(alias);
			return alias;
		}
	}
}

function maxAliasNumber(aliases: Iterable<string>): number {
	let max = 0;
	for (const alias of aliases) {
		const match = /^T-(\d+)$/i.exec(alias);
		if (!match) {
			continue;
		}
		max = Math.max(max, Number(match[1]));
	}
	return max;
}
