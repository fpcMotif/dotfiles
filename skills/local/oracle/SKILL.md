---
name: oracle
description: Use when the user asks for an oracle, second opinion, deep architectural sanity check, or decision-consistency review before committing to an approach.
---

# Oracle

Use this skill to obtain or emulate a high-context second opinion before major decisions.

## Pi workflow

When Pi subagents are available, delegate to the built-in `oracle` subagent with a focused prompt:

```text
Ask oracle to evaluate: context, options considered, recommendation, risks, and what would falsify the plan.
```

## Review frame

Ask the oracle to check:

1. Hidden assumptions.
2. Coupling and migration risks.
3. Failure modes and rollback path.
4. Whether the plan preserves user intent.
5. The smallest safe next step.

Return the synthesis, not a wall of raw debate. Call out disagreements plainly.
