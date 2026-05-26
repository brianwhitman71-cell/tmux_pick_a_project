---
description: Register the current tmux session as a long-running, rejoinable proj project
argument-hint: [project-name]
allowed-tools: Bash(proj:*), Bash(tmux:*)
---
The user wants to KEEP the current tmux session as a long-running project in the
`proj` switcher, so they can close the window and rejoin later with `pj <name>`.

Run: `proj here $ARGUMENTS`
(Omit the name to keep the session's current name; pass a name to rename + register it.)

This must run from inside the tmux session. The Bash tool inherits `$TMUX` from
the Claude Code process, so `proj here` targets the current session automatically.

After it succeeds, tell the user the exact rejoin command: `pj <name>`.

If `proj` is not found, the switcher isn't installed or on PATH — tell them to run
`~/Projects/tmux/install.sh` and open a new shell, then try again.
