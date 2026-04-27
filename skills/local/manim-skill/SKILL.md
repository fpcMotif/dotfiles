---
name: manim-skill
description: Use for Manim animation work: creating scenes, debugging layout, rendering frames/videos, and reviewing visual output for mathematical animations.
---

# Manim Skill

Use this skill when editing or reviewing Manim Community / ManimGL scenes.

## Workflow

1. Identify the Manim flavor from imports and commands:
   - `from manim import *` usually means Manim Community.
   - `from manimlib import *` usually means ManimGL.
2. Render the smallest useful target first:
   - still frame or low quality video before full production renders.
   - Example: `manim -ql path/to/file.py SceneName`.
3. Inspect visual output after meaningful changes. Check alignment, clipping, camera framing, text readability, timing, and color contrast.
4. Iterate with focused changes; avoid rewriting entire scenes unless requested.

## Rules

- Keep mathematical notation precise.
- Prefer named helper methods for repeated layout logic.
- Do not assume LaTeX or ffmpeg is installed; report missing dependencies clearly.
