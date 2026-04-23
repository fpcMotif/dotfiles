import { expect, test, describe, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { assertTaskVersion } from "./store";
import { serializeTaskFile } from "./schema";

describe("kanban store", () => {
	let tempDir: string;

	beforeEach(() => {
		tempDir = mkdtempSync(join(tmpdir(), "kanban-test-"));
	});

	afterEach(() => {
		rmSync(tempDir, { recursive: true, force: true });
	});

	describe("assertTaskVersion", () => {
		test("should not throw when version matches", () => {
			const piDir = join(tempDir, ".pi");
			const todosDir = join(piDir, "todos");
			mkdirSync(todosDir, { recursive: true });

			const taskMeta = {
				uuid: "123",
				alias: "T-001",
				title: "Test Task",
				status: "backlog" as const,
				priority: 3,
				tags: [],
				depends_on: [],
				created_at: "2023-01-01T00:00:00Z",
				updated_at: "2023-01-01T00:00:00Z",
				version: 1,
			};
			const taskContent = serializeTaskFile(taskMeta, "Body");
			const taskPath = join(todosDir, "t-001-test-task.md");
			writeFileSync(taskPath, taskContent);

			expect(() => assertTaskVersion(tempDir, "T-001", 1)).not.toThrow();
		});

		test("should throw when version mismatches", () => {
			const piDir = join(tempDir, ".pi");
			const todosDir = join(piDir, "todos");
			mkdirSync(todosDir, { recursive: true });

			const taskMeta = {
				uuid: "123",
				alias: "T-001",
				title: "Test Task",
				status: "backlog" as const,
				priority: 3,
				tags: [],
				depends_on: [],
				created_at: "2023-01-01T00:00:00Z",
				updated_at: "2023-01-01T00:00:00Z",
				version: 1,
			};
			const taskContent = serializeTaskFile(taskMeta, "Body");
			const taskPath = join(todosDir, "t-001-test-task.md");
			writeFileSync(taskPath, taskContent);

			expect(() => assertTaskVersion(tempDir, "T-001", 2)).toThrow(/expected version 2, found 1/);
		});

		test("should throw when task is not found", () => {
			const piDir = join(tempDir, ".pi");
			const todosDir = join(piDir, "todos");
			mkdirSync(todosDir, { recursive: true });

			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(/Task T-001 not found/);
		});

		test("should throw when board does not exist", () => {
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(/No kanban board found/);
		});
	});
});
