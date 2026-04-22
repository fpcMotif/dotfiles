import { expect, test, describe, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { assertTaskVersion } from "./store";
import { serializeTaskFile, taskFilename } from "./schema";
import type { TaskMeta } from "./types";

const BASE_META: TaskMeta = {
	uuid: "123",
	alias: "T-001",
	title: "Test Task",
	status: "backlog",
	priority: 3,
	tags: [],
	depends_on: [],
	created_at: "2023-01-01T00:00:00Z",
	updated_at: "2023-01-01T00:00:00Z",
	version: 1,
};

function seedTask(cwd: string, overrides: Partial<TaskMeta> = {}): TaskMeta {
	const meta: TaskMeta = { ...BASE_META, ...overrides };
	const todosDir = join(cwd, ".pi", "todos");
	mkdirSync(todosDir, { recursive: true });
	const path = join(todosDir, taskFilename(meta.alias, meta.title));
	writeFileSync(path, serializeTaskFile(meta, "Body"));
	return meta;
}

describe("kanban store", () => {
	let tempDir: string;

	beforeEach(() => {
		tempDir = mkdtempSync(join(tmpdir(), "kanban-test-"));
	});

	afterEach(() => {
		rmSync(tempDir, { recursive: true, force: true });
	});

	describe("assertTaskVersion", () => {
		test("does not throw when version matches", () => {
			seedTask(tempDir);
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).not.toThrow();
		});

		test("throws when version mismatches", () => {
			seedTask(tempDir);
			expect(() => assertTaskVersion(tempDir, "T-001", 2)).toThrow(/expected version 2, found 1/);
		});

		test("throws when task is not found", () => {
			mkdirSync(join(tempDir, ".pi", "todos"), { recursive: true });
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(/Task T-001 not found/);
		});

		test("throws when board does not exist", () => {
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(/No kanban board found/);
		});
	});
});
