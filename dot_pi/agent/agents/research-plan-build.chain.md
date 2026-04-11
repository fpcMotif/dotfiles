---
name: research-plan-build
description: Research external context, gather code context, plan, and implement
---

## researcher
output: research.md

Research: {task}

## context-builder
reads: research.md
output: context.md

Build code context informed by research: {previous}

## planner
reads: context.md+research.md
output: plan.md

Create implementation plan using research and code context: {previous}

## worker
reads: context.md+plan.md+research.md
progress: true

Implement the plan: {previous}
