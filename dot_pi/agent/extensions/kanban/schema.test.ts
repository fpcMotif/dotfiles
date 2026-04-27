import { expect, test, describe } from "bun:test";
import {
	isTaskStatus,
	isWipStatus,
	parseBoardConfig,
	parseTaskFile,
	tryParseLegacyTaskFile,
	serializeTaskFile,
	validateTaskForWrite,
	taskFilename,
	slugify,
	formatAlias,
	aliasNumber,
	normalizeTaskReference,
	compareTasks,
	DEFAULT_CONFIG,
	DEFAULT_TASK_BODY,
} from "./schema";
import { TASK_STATUSES } from "./types";
import type { StoredTask, TaskStatus, WipStatus } from "./types";

describe("kanban schema utilities", () => {
	test("isTaskStatus", () => {
		for (const status of TASK_STATUSES) {
			expect(isTaskStatus(status)).toBe(true);
		}
		expect(isTaskStatus("invalid")).toBe(false);
		expect(isTaskStatus("")).toBe(false);
		expect(isTaskStatus(123)).toBe(false);
		expect(isTaskStatus(null)).toBe(false);
		expect(isTaskStatus(undefined)).toBe(false);
		expect(isTaskStatus({})).toBe(false);
		expect(isTaskStatus([])).toBe(false);
	});

	test("isWipStatus", () => {
		expect(isWipStatus("doing")).toBe(true);
		expect(isWipStatus("review")).toBe(true);
		expect(isWipStatus("backlog")).toBe(false);
		expect(isWipStatus("done")).toBe(false);
		expect(isWipStatus("invalid")).toBe(false);
	});

	test("slugify", () => {
		expect(slugify("Hello World")).toBe("hello-world");
		expect(slugify("Task #123!")).toBe("task-123");
		expect(slugify("---Multiple---Dashes---")).toBe("multiple-dashes");
		expect(slugify("")).toBe("task");
		expect(slugify("   ")).toBe("task");
		expect(slugify("a".repeat(100))).toHaveLength(60);
	});

	test("formatAlias", () => {
		expect(formatAlias(1)).toBe("T-001");
		expect(formatAlias(123)).toBe("T-123");
		expect(formatAlias(1234)).toBe("T-1234");
	});

	test("aliasNumber", () => {
		expect(aliasNumber("T-001")).toBe(1);
		expect(aliasNumber("T-123")).toBe(123);
		expect(aliasNumber("t-042")).toBe(42);
		expect(aliasNumber("INVALID")).toBeNaN();
		expect(aliasNumber("T-ABC")).toBeNaN();
	});

	test("normalizeTaskReference", () => {
		expect(normalizeTaskReference("T-1")).toBe("T-001");
		expect(normalizeTaskReference("T-01")).toBe("T-001");
		expect(normalizeTaskReference("T-123")).toBe("T-123");
		expect(normalizeTaskReference("#1")).toBe("T-001");
		expect(normalizeTaskReference("1")).toBe("T-001");
		expect(normalizeTaskReference("random")).toBe("random");
	});

	test("compareTasks", () => {
		const t1: StoredTask = {
			meta: {
				uuid: "1",
				alias: "T-001",
				title: "A",
				status: "backlog",
				priority: 5,
				created_at: "2023-01-01T00:00:00Z",
				updated_at: "2023-01-01T00:00:00Z",
				tags: [],
				depends_on: [],
				version: 1,
			},
			body: "",
			filename: "",
			path: "",
		};
		const t2: StoredTask = { ...t1, meta: { ...t1.meta, status: "ready", uuid: "2" } };
		const t3: StoredTask = { ...t1, meta: { ...t1.meta, priority: 1, uuid: "3" } };
		const t4: StoredTask = { ...t1, meta: { ...t1.meta, alias: "T-002", uuid: "4" } };
		const t5: StoredTask = { ...t1, meta: { ...t1.meta, created_at: "2023-01-02T00:00:00Z", uuid: "5" } };

		// Status order: backlog < ready < doing < review < blocked < done
		expect(compareTasks(t1, t2)).toBeLessThan(0);
		// Priority: 1 < 5
		expect(compareTasks(t3, t1)).toBeLessThan(0);
		// Alias: T-001 < T-002
		expect(compareTasks(t1, t4)).toBeLessThan(0);
		// Created at: 2023-01-01 < 2023-01-02
		expect(compareTasks(t1, t5)).toBeLessThan(0);
	});

	test("taskFilename", () => {
		expect(taskFilename("T-001", "Hello World")).toBe("t-001-hello-world.md");
	});
});

describe("kanban schema parsing", () => {
	test("parseBoardConfig", () => {
		const config = parseBoardConfig('{"wip":{"doing":5}}', "test.json");
		expect(config.wip.doing).toBe(5);
		expect(config.wip.review).toBe(DEFAULT_CONFIG.wip.review);

		expect(() => parseBoardConfig("invalid", "test.json")).toThrow(/invalid JSON/);
		expect(() => parseBoardConfig("[]", "test.json")).toThrow(/must be a JSON object/);
		expect(() => parseBoardConfig('{"wip":{"invalid":1}}', "test.json")).toThrow(/unsupported WIP lane/);
		expect(() => parseBoardConfig('{"wip":{"doing":0}}', "test.json")).toThrow(/must be a positive integer/);
	});

	test("parseTaskFile & serializeTaskFile", () => {
		const meta = {
			uuid: "123",
			alias: "T-001",
			title: "Test Task",
			status: "backlog" as const,
			priority: 3,
			tags: ["tag1", "tag2"],
			depends_on: ["T-002"],
			created_at: "2023-01-01T00:00:00Z",
			updated_at: "2023-01-01T00:00:00Z",
			version: 1,
		};
		const body = "Some body content";
		const serialized = serializeTaskFile(meta, body);
		expect(serialized).toContain('"uuid": "123"');
		expect(serialized).toContain("Some body content");

		const parsed = parseTaskFile(serialized, "test.md");
		expect(parsed.meta).toEqual(meta);
		expect(parsed.body).toBe(body);
	});

	test("parseTaskFile with defaults", () => {
		const content = `---
{
  "uuid": "123",
  "alias": "T-001",
  "title": "Minimal",
  "status": "ready",
  "priority": 1,
  "tags": [],
  "depends_on": [],
  "created_at": "...",
  "updated_at": "...",
  "version": 1
}
---
`;
		const parsed = parseTaskFile(content, "test.md");
		expect(parsed.body).toBe(DEFAULT_TASK_BODY.trimEnd());
	});

	test("tryParseLegacyTaskFile", () => {
		const content = `---
{
  "id": "001",
  "title": "Legacy",
  "status": "doing",
  "priority": 5,
  "created": "2023-01-01T00:00:00Z",
  "updated": "2023-01-01T00:00:00Z",
  "assignee": "me",
  "tags": ["old"],
  "blocked_by": []
}
---
Legacy body`;
		const parsed = tryParseLegacyTaskFile(content, "test.md");
		expect(parsed).not.toBeNull();
		expect(parsed?.meta.id).toBe("001");
		expect(parsed?.body).toBe("Legacy body");

		const modernContent = serializeTaskFile(
			{
				uuid: "1",
				alias: "T-001",
				title: "Modern",
				status: "done",
				priority: 1,
				tags: [],
				depends_on: [],
				created_at: "...",
				updated_at: "...",
				version: 1,
			},
			"Modern body",
		);
		expect(tryParseLegacyTaskFile(modernContent, "test.md")).toBeNull();
	});

	test("validateTaskForWrite", () => {
		const meta = {
			uuid: "123",
			alias: "T-001",
			title: "Test Task",
			status: "backlog" as const,
			priority: 3,
			tags: ["tag1"],
			depends_on: [],
			created_at: "2023-01-01T00:00:00Z",
			updated_at: "2023-01-01T00:00:00Z",
			version: 1,
		};
		const body = "Body";
		const validated = validateTaskForWrite(meta, body, "test.md");
		expect(validated.meta).toEqual(meta);
		expect(validated.body).toBe(body);
	});
});
