---
description: Under --auto, phase K still stops for an untracked path outside codeRoots, names it, and commits nothing.
tags: [gate, k]
runs: 1
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Bash]
---

/pipeline --resume --auto
