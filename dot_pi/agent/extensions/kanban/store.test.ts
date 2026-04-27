import {
	afterEach,
	beforeEach,
	describe,
	expect,
	mock,
	spyOn,
	test,
} from "bun:test";
import * as fs from "node:fs";
import {
	mkdirSync,
	mkdtempSync,
	readFileSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import * as schema from "./schema";
import { serializeTaskFile, taskFilename } from "./schema";
import { assertTaskVersion, createTask, moveTask } from "./store";
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
		mock.restore();
	});

	describe("assertTaskVersion", () => {
		test("does not throw when version matches", () => {
			seedTask(tempDir);
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).not.toThrow();
		});

		test("throws when version mismatches", () => {
			seedTask(tempDir);
			expect(() => assertTaskVersion(tempDir, "T-001", 2)).toThrow(
				/expected version 2, found 1/,
			);
		});

		test("throws when task is not found", () => {
			mkdirSync(join(tempDir, ".pi", "todos"), { recursive: true });
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(
				/Task T-001 not found/,
			);
		});

		test("throws when board does not exist", () => {
			expect(() => assertTaskVersion(tempDir, "T-001", 1)).toThrow(
				/No kanban board found/,
			);
		});
	});
	describe("error handling", () => {
		test("persistTaskUpdate restores original file when appendEvent throws and paths are the same", () => {
			seedTask(tempDir);
			spyOn(fs, "appendFileSync").mockImplementation(() => {
				throw new Error("Simulated appendFileSync failure");
			});
			const path = join(tempDir, ".pi", "todos", "t-001-test-task.md");
			const originalContent = readFileSync(path, "utf-8");
			expect(() => moveTask(tempDir, "T-001", "doing")).toThrow(
				"Simulated appendFileSync failure",
			);
			const currentContent = readFileSync(path, "utf-8");
			expect(currentContent).toBe(originalContent);
		});

		test("persistTaskUpdate removes new file and restores old when paths differ and appendEvent throws", () => {
			seedTask(tempDir);
			spyOn(schema, "taskFilename").mockImplementation(
				() => "t-001-moved-task.md",
			);
			spyOn(fs, "appendFileSync").mockImplementation(() => {
				throw new Error("Simulated throw after writing different path");
			});
			const oldPath = join(tempDir, ".pi", "todos", "t-001-test-task.md");
			const originalContent = readFileSync(oldPath, "utf-8");
			const newPath = join(tempDir, ".pi", "todos", "t-001-moved-task.md");

			expect(() => moveTask(tempDir, "T-001", "doing")).toThrow(
				"Simulated throw after writing different path",
			);
			expect(fs.existsSync(newPath)).toBe(false);
			expect(fs.existsSync(oldPath)).toBe(true);
			const currentContent = readFileSync(oldPath, "utf-8");
			expect(currentContent).toBe(originalContent);
		});

		test("persistTaskUpdate restores old file when unlinkSync throws and paths differ", () => {
			seedTask(tempDir);
			spyOn(schema, "taskFilename").mockImplementation((_alias, _title) => {
				return "t-001-moved-task.md"; // force the path to differ
			});

			const _unlinkSync = fs.unlinkSync;
			spyOn(fs, "unlinkSync").mockImplementation((path) => {
				if (path.toString().endsWith("t-001-test-task.md")) {
					throw new Error("Simulated unlinkSync failure");
				}
				return _unlinkSync(path);
			});

			const oldPath = join(tempDir, ".pi", "todos", "t-001-test-task.md");
			const originalContent = readFileSync(oldPath, "utf-8");
			const newPath = join(tempDir, ".pi", "todos", "t-001-moved-task.md");

			expect(() => moveTask(tempDir, "T-001", "doing")).toThrow(
				"Simulated unlinkSync failure",
			);
			expect(fs.existsSync(newPath)).toBe(false);
			expect(fs.existsSync(oldPath)).toBe(true);
			const currentContent = readFileSync(oldPath, "utf-8");
			expect(currentContent).toBe(originalContent);
		});

		test("createTask removes new file when appendEvent throws", () => {
			spyOn(fs, "appendFileSync").mockImplementation(() => {
				throw new Error("Simulated appendEvent failure on create");
			});
			const expectedPath = join(
				tempDir,
				".pi",
				"todos",
				"t-001-new-failed-task.md",
			);
			expect(() =>
				createTask(tempDir, { title: "New Failed Task", priority: 3 }),
			).toThrow("Simulated appendEvent failure on create");
			expect(fs.existsSync(expectedPath)).toBe(false);
		});
	});
});
