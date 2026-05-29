# proj — a project-centric tmux switcher for a fleet of machines

Stop thinking about *which host* or *which tmux session* you were in. Think in
**projects**. One short command (`pj`) lists every project across your machines,
and jumping into one *just works* — `switch-client`/`attach` if it's on this box,
a transparent `ssh` hop if it's on another. Close the window whenever you want;
the session (and anything running in it, like a Claude Code agent) keeps running.
Come back with the same command. Sessions even rebuild themselves after a reboot.

Built to kill three frictions:

1. Landing in the **wrong session** and doing things in the wrong place.
2. **Losing work on reboot** — tmux sessions don't survive a restart by default.
3. Wanting to **close the laptop / drop SSH / switch machines** mid-task and have
   the work keep going, reachable from anywhere on the fleet.

---

## Quick start

```bash
git clone <your-repo-url> ~/Projects/tmux
~/Projects/tmux/install.sh
exec $SHELL          # pick up the alias + completion

pj                   # pick a project and jump in
```

`pj` is the alias for `proj` (chosen so it won't collide with a common
`p='cd ~/Projects'`).

---

## Commands

| Command | What it does |
|---|---|
| `pj` | fzf picker of **all** fleet projects (● live, ○ stopped, cyan host = remote); pick to jump |
| `pj <name>` | jump straight in — local or remote, it figures out which |
| `pj ls` | table of every project across this host + peers, with status |
| `pj here [name] [cmd]` | register the session **you're in** as a project (this host) |
| `pj add <name> [dir] [cmd]` | register a project on this host (`dir` defaults to `$PWD`) |
| `pj rm <name>` | retire a project on this host (asks before killing a live session) |
| `pj -h` | help |

`<TAB>` completes project names and subcommands. Inside tmux, **`prefix + p`**
(default prefix `Ctrl-b`) opens the picker in a popup.

### `pj here` — keep the session you're in

```
pj here blamethe
│  │    └── a name YOU choose → tmux session name + how you return (pj blamethe)
│  └── "use the session I'm in right now" (reads host = this box, dir = current path)
└── the command
```

Omit the name to keep the current session name. From **inside Claude Code**, the
`/keep [name]` slash command does the same thing.

---

## Detach, walk away, come back

Running something long (a build, a Claude Code agent turn)? Just leave.

- **Detach:** `Ctrl-b` then `d`. Disconnects your *view*, not the process.
- Closing the terminal window or dropping SSH does the same — none of it kills
  the session.
- **Come back:** `pj <name>` (or `pj` and pick the ● one) — from *any* machine.

Detach is **not** pause: a mid-task agent keeps going; an idle one keeps waiting.

---

## The fleet (cross-host)

Each machine owns its own projects. `pj` shows the **union** across the fleet and
routes you to the right box:

- Local project → `switch-client` (if you're in tmux) or `attach`.
- Remote project → `ssh -t <host> proj-attach <name>`; detach (`Ctrl-b d`) drops
  you back where you started.

**Jumping to a remote project while already inside tmux** opens it *nested* (a
remote tmux drawn inside your local pane — there's no way to switch a client
across servers). `proj` warns you and tells you the keys: drive the inner
(remote) session with a **double prefix** `Ctrl-b Ctrl-b <key>`, and return with
`Ctrl-b Ctrl-b d` — a plain `Ctrl-b d` detaches your *local* box instead. The two
status bars (local vs remote `#h`) tell you which one you're typing into.

Which machines are in the fleet is set by [`peers`](peers.example) — one short
hostname (`hostname -s`) per line; each host skips itself, so the same file works
everywhere. **Requires passwordless SSH between the listed hosts.** With `peers`
empty/commented, `proj` simply runs single-host.

The list is assembled live: each host reads the others' registries and `tmux ls`
over SSH, in parallel, cached ~5s, with a short timeout so an unreachable peer
can't hang the picker — nothing to keep in sync.

---

## Surviving reboots

On Linux, the installer sets up a `systemd --user` service, `tmux-projects`, that
runs [`bin/proj-boot`](bin/proj-boot) at boot. It recreates this host's sessions
and re-runs each one's `startcmd`. With the default `cccc`
(`claude --dangerously-skip-permissions -c`), Claude Code resumes the last
conversation in that directory. Works without login because **user lingering** is
enabled (the installer turns it on).

> ⚠️ With `cccc` as the startcmd, a freshly-booted unattended box auto-launches
> Claude Code with `--dangerously-skip-permissions` — no prompts. Change a
> project's startcmd in `projects.tsv` if you don't want that (e.g.
> `claude --continue`, or blank for a plain shell).

In-memory process state can't be snapshotted; what survives is the session layout
+ working dir (recreated) and the Claude *conversation* (resumed from disk).

---

## When you're NOT in tmux

`pj <name>` handles every case:

- **In tmux** → `switch-client` (no nesting).
- **Plain terminal, not in tmux** → it attaches you (the normal path).
- **No terminal at all** (a script, or a tool's non-interactive shell) → it can't
  attach, so it ensures the session exists and tells you exactly how to get in:
  `Open it from an interactive shell with: pj <name>`.
- **`pj here` with no tmux** → there's no session to keep; it tells you how to
  start one (`pj add … && pj …`, or `tmux new -s …` then `pj here`).

---

## Use from inside Claude Code: `/keep`

[`commands/keep.md`](commands/keep.md) is a user-level slash command. Install once:

```bash
cp commands/keep.md ~/.claude/commands/keep.md
```

Then from a Claude Code session running **inside tmux**:

```
/keep myproject
```

It runs `proj here myproject` (the Bash tool inherits `$TMUX`, so it targets the
current session). Check you're in tmux first with `echo $TMUX`.

---

## The registry

A tab-separated file, `projects.tsv`, one line per project on this host:

```
name <TAB> host <TAB> dir <TAB> startcmd
```

- **Gitignored**, per-host, seeded from [`projects.tsv.example`](projects.tsv.example)
  on first install. Edit by hand (real tabs) or with `pj add` / `pj here`.
- A host only acts on rows where `host` == its own `hostname -s`; foreign rows are
  ignored locally and reported by the host that owns them.
- `startcmd` is typed into the session's shell on first create. `cccc` is an alias
  (`claude --dangerously-skip-permissions -c`); use any command, or leave blank.
- Names may contain dots (e.g. `nixfred.com`). tmux can't use `.`/`:` in a session
  name (they're target separators), so the tmux session is named with those mapped
  to `_` (`nixfred.com` → session `nixfred_com`). You always type the real name
  (`pj nixfred.com`); the mapping is internal.

---

## How it works

| File | Role |
|---|---|
| [`bin/proj`](bin/proj) | the CLI: picker, fleet-aware jump, `ls`, `here`, `add`, `rm` |
| [`bin/proj-attach`](bin/proj-attach) | (per host) ensure session, then switch-client / attach / guide |
| [`bin/proj-status`](bin/proj-status) | fleet status for the picker & `ls` (local + peers over SSH) |
| [`bin/proj-boot`](bin/proj-boot) | boot-time session rebuild, run by the systemd service |
| [`bin/proj-completion.bash`](bin/proj-completion.bash) | bash tab-completion for `pj` |
| [`tmux.conf`](tmux.conf) | loud project name in status bar + popup picker keybind |
| [`systemd/tmux-projects.service`](systemd/tmux-projects.service) | user service running `proj-boot` at boot |
| [`install.sh`](install.sh) | idempotent installer |
| [`commands/keep.md`](commands/keep.md) | the `/keep` Claude Code slash command |

The loud orange block at the left of the tmux status bar always shows the current
session name, so you stop acting in the wrong one.

### What the installer does

Verifies deps (`tmux`, `fzf`; warns on missing `claude`); seeds `projects.tsv` and
`peers` from the examples; symlinks `~/.tmux.conf`; appends a marker-guarded
`~/.bashrc` block (PATH, `alias pj=proj`, completion, SSH-login auto-picker);
installs + enables the `tmux-projects` user service and ensures lingering (Linux).
macOS launchd is not implemented yet (it warns).

---

## Install / deploy

On the box itself: `~/Projects/tmux/install.sh`

To another host (note the exclude — each box keeps its own registry):
```bash
rsync -a --exclude=projects.tsv ~/Projects/tmux/ <host>:~/Projects/tmux/
ssh <host> 'bash ~/Projects/tmux/install.sh'
```
Then add the host to `peers` on each box. Requirements: `tmux` (3.2+ for the
popup), `fzf`, bash, passwordless SSH between fleet hosts. Linux for the boot
service / `claude` if you use `cccc` startcmds.

---

## Roadmap

- **macOS** launchd boot service (the installer currently warns on Darwin).
- Optionally git-back the registries instead of each host owning its own.

---

## Troubleshooting

- **`pj: command not found`** — `exec $SHELL` or `source ~/.bashrc`.
- **Picker/`ls` doesn't show another host** — add it to `peers` on both boxes and
  confirm passwordless SSH works *both* directions (`ssh <host> hostname`).
- **`proj here: you're not inside tmux`** — `echo $TMUX` is empty; start under tmux.
- **Picker empty** — no projects registered for this host; use `pj add`/`pj here`.
- **Boot sessions didn't return** — `systemctl --user status tmux-projects` and
  `loginctl show-user "$USER" | grep Linger=yes`.
