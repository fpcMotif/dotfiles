---
name: plan-build
description: Fast two-step — scout and plan, then implement
---

## scout
output: context.md

Analyze the codebase for {task}

## planner
reads: context.md
output: plan.md

Create an implementation plan based on {previous}

## worker
reads: context.md+plan.md
progress: true

Implement the plan: {previous}
