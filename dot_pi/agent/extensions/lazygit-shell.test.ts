import { expect, test, describe } from "bun:test";
import { isLazygitCommand, normalizeCommand } from "./lazygit-shell";

describe("lazygit-shell helpers", () => {
	test("isLazygitCommand", () => {
		expect(isLazygitCommand("lazygit")).toBe(true);
		expect(isLazygitCommand("lazygit ")).toBe(true);
		expect(isLazygitCommand("  lazygit  ")).toBe(true);
		expect(isLazygitCommand("lazygit status")).toBe(true);
		expect(isLazygitCommand("lazygit\tstatus")).toBe(true);
		expect(isLazygitCommand("lg")).toBe(true);
		expect(isLazygitCommand("lg status")).toBe(true);
		expect(isLazygitCommand("")).toBe(false);
		expect(isLazygitCommand("l")).toBe(false);
		expect(isLazygitCommand("git")).toBe(false);
		expect(isLazygitCommand("lazygitstatus")).toBe(false);
		expect(isLazygitCommand("lgstatus")).toBe(false);
	});

	test("normalizeCommand", () => {
		expect(normalizeCommand("lg")).toBe("lazygit");
		expect(normalizeCommand("lg status")).toBe("lazygit status");
		expect(normalizeCommand("  lg status  ")).toBe("lazygit status");
		expect(normalizeCommand("lazygit")).toBe("lazygit");
		expect(normalizeCommand("lazygit status")).toBe("lazygit status");
		// Edge cases
		expect(normalizeCommand("not-lazygit")).toBe("not-lazygit");
	});
});
