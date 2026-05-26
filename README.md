# proj — a project-centric tmux session switcher

Stop thinking about *which host* or *which tmux session* you were in. Think in
**projects**. One short command picks a project from a list and drops you into
its tmux session. Close the window whenever you want — the session (and anything
running in it, like a Claude Code agent) keeps running on the host. Come back
with the same command. Sessions even rebuild themselves after a reboot.

It was built to solve three specific pains:

1. Landing in the **wrong session** and doing things in the wrong place.
2. **Losing work on reboot** — tmux sessions don't survive a restart by default.
3. Wanting to **close the laptop / drop SSH** mid-task and have the work keep going.

---

## Quick start

```bash
git clone <your-repo-url> ~/Projects/tmux
~/Projects/tmux/install.sh
exec $SHELL          # or open a new shell, to pick up the alias

pj                   # pick a project and jump in
```

`pj` is the alias for `proj` (chosen so it doesn't collide with a common
`p='cd ~/Projects'`). Everything below uses `pj`.

---

## Commands

| Command | What it does |
|---|---|
| `pj` | fzf picker of this host's projects (● live, ○ stopped); pick one to jump in |
| `pj <name>` | jump straight into that project's session |
| `pj ls` | list this host's registered projects |
| `pj here [name] [cmd]` | register the session **you're sitting in** as a project |
| `pj add <name> [dir] [cmd]` | register a project (`dir` defaults to `$PWD`) |
| `pj rm <name>` | retire a project (asks before killing a live session) |
| `pj -h` | help |

Inside tmux, **`prefix + p`** (default prefix is `Ctrl-b`) opens the picker in a
popup.

### `pj here` — keep the session you're in

The most common way to register something. You're already working in a tmux
session and decide it's worth keeping:

```
pj here blamethe
│  │    └── a name YOU choose. It becomes: the tmux session name, the registry
│  │        entry, and how you return later → `pj blamethe`
│  └── "use the session I'm in right now" (reads host = this box, dir = current path)
└── the command
```

Output:
```
registered 'blamethe' -> /home/me/Projects/blamethe  (cccc)
rejoin anytime with:  pj blamethe
```

Omit the name (`pj here`) to keep the session's current name. Add a 4th word to
override the relaunch command (defaults to `cccc`).

You can also run it from **inside Claude Code** with the `/keep [name]` slash
command (see below).

---

## Detach, walk away, come back

Running something long (a build, a Claude Code agent turn)? Just leave.

**Jump out (detach):** `Ctrl-b` then `d`.

This disconnects your *view*, not the process. Whatever is running keeps
running on the host. The same is true if you simply **close the terminal
window** or **let your SSH connection drop** — none of those kill the session.

**Come back:**
```bash
pj blamethe      # or: pj  (the picker shows ● for running sessions)
```

Detach is **not** pause: a mid-task agent keeps going; an idle one keeps
waiting. The only things that stop a session are quitting the program, killing
the session (`pj rm` / `tmux kill-session`), or a reboot — and reboots are
covered (below).

---

## Surviving reboots

On Linux, the installer sets up a `systemd --user` service, `tmux-projects`,
that runs [`bin/proj-boot`](bin/proj-boot) at boot. It recreates each of *this
host's* sessions and re-runs each one's `startcmd`. Because the default startcmd
is `cccc` (`claude --dangerously-skip-permissions -c`), Claude Code resumes the
last conversation in that directory.

This works without you logging in because **user lingering** is enabled
(`loginctl enable-linger`), which the installer turns on.

> ⚠️ With `cccc` as the startcmd, a freshly-booted unattended box will
> auto-launch Claude Code with `--dangerously-skip-permissions` — no prompts.
> Change the startcmd in `projects.tsv` if you don't want that for a given
> project (e.g. `claude --continue`, or a plain shell with no command).

What does **not** survive a reboot: the live in-memory state of a process can't
be snapshotted. What survives is the session layout + working dir (recreated)
and the Claude *conversation* (resumed from disk). The process itself is fresh.

---

## Use from inside Claude Code: `/keep`

[`commands/keep.md`](commands/keep.md) is a user-level Claude Code slash command.
Install it once:

```bash
cp commands/keep.md ~/.claude/commands/keep.md
```

Then, from any Claude Code session running inside tmux:

```
/keep myproject
```

It runs `proj here myproject` for you (the Bash tool inherits `$TMUX`, so it
targets the current session). Prerequisite: Claude Code must be running **inside
tmux** — check with `echo $TMUX` (non-empty = good). If it isn't, there's no
session to keep; start future work via `pj`, which always lands you in tmux.

---

## The registry

A single tab-separated file, `projects.tsv`, one line per project:

```
name <TAB> host <TAB> dir <TAB> startcmd
```

Example:
```
blamethe	red	/home/me/Projects/blamethe	cccc
```

- **It is gitignored.** Each machine keeps its own untracked copy, seeded from
  [`projects.tsv.example`](projects.tsv.example) on first install. Edit by hand
  (use real tabs) or with `pj add` / `pj here`.
- `host` = `hostname -s`. `proj` only shows and acts on rows for the current
  host (single-host model, see below).
- `startcmd` is typed into the session's shell on first create. `cccc` is an
  alias (`claude --dangerously-skip-permissions -c`); use any command you like,
  or leave it blank for a plain shell.

---

## How it works

| File | Role |
|---|---|
| [`bin/proj`](bin/proj) | the CLI: picker, jump, `ls`, `here`, `add`, `rm` |
| [`bin/proj-attach`](bin/proj-attach) | ensure the session exists, then `switch-client` (if already in tmux) or `attach` |
| [`bin/proj-status`](bin/proj-status) | live ●/○ status for the picker (queries local `tmux ls`) |
| [`bin/proj-boot`](bin/proj-boot) | boot-time session rebuild, run by the systemd service |
| [`tmux.conf`](tmux.conf) | loud project name in the status bar + popup picker keybind |
| [`systemd/tmux-projects.service`](systemd/tmux-projects.service) | user service that runs `proj-boot` at boot |
| [`install.sh`](install.sh) | idempotent installer |
| [`commands/keep.md`](commands/keep.md) | the `/keep` Claude Code slash command |

The **jump primitive** is `proj-attach`: it creates the session detached if
needed (capturing the new pane id so the startcmd is sent reliably), then either
`switch-client` (when you're already inside tmux, e.g. the popup) or `attach`
(from a plain shell). The loud orange block at the left of the tmux status bar
always shows the current session name, so you stop acting in the wrong one.

### What the installer does

- Verifies deps (`tmux`, `fzf`; warns if `claude` isn't found).
- Seeds `projects.tsv` from the example if absent.
- Symlinks `~/.tmux.conf` → this repo's `tmux.conf` (won't clobber an existing
  real file; tells you the `source-file` line to add instead).
- Appends a marker-guarded block to `~/.bashrc`: adds `bin/` to `PATH`, defines
  `alias pj=proj`, and an opt-out SSH-login auto-picker.
- Installs + enables the `tmux-projects` user service (Linux) and ensures
  lingering. On macOS it notes that the launchd service isn't implemented yet.

### SSH-login auto-picker

When you SSH into an installed box and aren't already in tmux, the picker opens
automatically (the "easy to get back" behavior). Disable per-shell with
`PROJ_NO_AUTOPICK=1`, or remove the block from `~/.bashrc`.

---

## Install / deploy

On the box itself:
```bash
~/Projects/tmux/install.sh
```

To another host (single-host model — each box manages its own projects):
```bash
rsync -a ~/Projects/tmux/ <host>:~/Projects/tmux/
ssh <host> 'bash ~/Projects/tmux/install.sh'
```

Requirements: `tmux` (3.2+ for the popup), `fzf`, bash. Linux for the boot
service. `claude` only if you use `cccc`-style startcmds.

---

## Model & roadmap

**Single-host, by design (for now).** Each machine manages its own projects;
`pj` only shows/acts on the current host. The `host` column already exists in the
registry so cross-host jumping slots in without changing the file format.

Deferred:

- **Cross-host jump** — `ssh -t <host> proj-attach <name>` so `pj` can route you
  to a project on another box, plus fleet-wide live status in the picker.
- **Shared registry** — git-backed/synced instead of a per-host copy.
- **macOS** — a launchd boot service (the installer currently warns on Darwin).

---

## Troubleshooting

- **`pj: command not found`** — open a new shell or `source ~/.bashrc` (the alias
  is added by the installer).
- **`proj here: run this inside the tmux session…`** — you're not in tmux;
  `echo $TMUX` is empty. Start under tmux first.
- **Picker is empty** — no projects registered for this host yet. Use `pj add` or
  `pj here`, or check `hostname -s` matches the `host` column.
- **Boot sessions didn't come back** — check the service:
  `systemctl --user status tmux-projects` and confirm
  `loginctl show-user "$USER" | grep Linger=yes`.
