import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerKanbanCommands } from "./commands";
import { registerKanbanHooks } from "./hooks";
import { registerKanbanTools } from "./tool";

export default function kanbanExtension(pi: ExtensionAPI): void {
	registerKanbanCommands(pi);
	registerKanbanTools(pi);
	registerKanbanHooks(pi);
}
