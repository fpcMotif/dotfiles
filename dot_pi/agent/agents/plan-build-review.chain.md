---
name: plan-build-review
description: Full development cycle — scout context, plan, implement, and review
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

## reviewer
reads: plan.md+progress.md
progress: true

Review implementation against the plan: {previous}
