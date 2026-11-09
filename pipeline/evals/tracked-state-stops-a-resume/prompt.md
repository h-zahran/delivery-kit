---
description: A resume whose state file is tracked in git stops before any recorded answer is used, under --auto too, and commits nothing.
tags: [gate, resume]
runs: 1
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Bash]
---

/pipeline --resume --auto
