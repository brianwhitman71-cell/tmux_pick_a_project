<div align="center">

# 🛰️  tmux_pick_a_project

### Think in **projects**, not hosts and sessions.

**One short alias picks a project from any machine in your fleet,
drops you into its live tmux session, and lets you walk away.
Close the lid. Switch boxes. Come back exactly where you left off —
agent still running, conversation still in context, no ceremony.**

![bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![tmux 3.2+](https://img.shields.io/badge/tmux-3.2%2B-1BB91F?logo=tmux&logoColor=white)
![fzf](https://img.shields.io/badge/fzf-required-ff69b4)
![Linux](https://img.shields.io/badge/platform-Linux-FCC624?logo=linux&logoColor=black)
![macOS soon](https://img.shields.io/badge/macOS-soon-lightgrey?logo=apple&logoColor=white)
![status](https://img.shields.io/badge/status-works%20on%20my%20fleet-brightgreen)

</div>

---

## ✨ What it looks like

```
$ pj
  project>
> ●  auth-api          (laptop)   ~/work/auth-api
  ●  infra-tf          (laptop)   ~/work/infra-tf
  ●  daily-scrape      (server)   ~/jobs/daily-scrape
  ○  payments-svc      (server)   ~/work/payments-svc
  ●  one-off-script    (laptop)   ~/scratch/one-off
  5/5  ───────────────────────────────────────────────────────────────────────
  enter = jump   │   ● live    ○ stopped   │   (cyan host) = remote, via ssh
```

Fuzzy-pick a project, hit enter — you're **in**. If it lives on this box,
that's a `switch-client`/`attach`. If it lives on another box on your tailnet,
it's a transparent `ssh -t` hop. **You never type a hostname.**

---

## 🩹 The pain this kills

| | |
|---|---|
| 😵‍💫 | Landing in the **wrong** tmux session and doing things in the wrong place |
| 💀 | Losing the in-flight work on **reboot** — tmux doesn't survive a restart by default |
| 🧳 | Wanting to **close the laptop / drop SSH / move boxes** mid-task without losing the running agent, build, or REPL |

If you live in a terminal with long-running Claude Code / Cursor / aider /
ipython / dev-server sessions across more than one machine, this is for you.

---

## 🚀 Quick install

```bash
git clone https://github.com/nixfred/tmux_pick_a_project ~/Projects/tmux
~/Projects/tmux/install.sh
exec $SHELL                # pick up the alias + tab-completion
pj                         # 🎯 you're in
```

Run the same two commands on every box in your fleet. The installer is
idempotent and only touches:

- `~/.tmux.conf` — symlinked (won't clobber an existing real file)
- `~/.bashrc` — a marker-guarded block (PATH + `alias pj=proj` + completion + optional SSH-login picker)
- `~/.config/systemd/user/tmux-projects.service` — the reboot rebuilder
- `~/Projects/tmux/projects.tsv` & `peers` — seeded from `.example` files (gitignored)

---

## 🤖 Have your AI install it for you

Don't want to read further? Point your coding agent at this repo:

> **"Install `https://github.com/nixfred/tmux_pick_a_project` for me, and add the hosts I want to be able to jump between to the `peers` file."**

**Claude Code, Cursor, Codex, Aider, Continue** — any of them can clone the
repo, run `install.sh`, edit `peers` for your fleet, repeat on each host over
SSH, and (for Claude Code) copy the `/keep` slash command into
`~/.claude/commands/`.

Then, from inside any tmux+agent session, just say:

> **"Keep this session as a pj called `auth-api`."**

The agent runs `pj here auth-api`. Now `pj auth-api` reattaches it forever —
across reboots, across machines.

> 💡 Inside Claude Code, the shortcut is **`/keep auth-api`**.

---

## 🎛️ Commands

| Command | What it does |
|---|---|
| `pj` | Fuzzy picker of every project across the fleet; pick to jump |
| `pj <name>` | Jump straight in — local or remote, it figures out which |
| `pj ls` | Table of every project, with live ●/○ status |
| `pj here [name] [cmd]` | **Keep the session you're in** as a long-running project |
| `pj add <name> [dir] [cmd]` | Register a project here (`dir` defaults to `$PWD`) |
| `pj rm <name>` | Retire a project (asks before killing a live session) |
| `pj -h` | Help |

`<TAB>` completes project names. Inside tmux, **`prefix + p`** (default
`Ctrl-b`) opens the picker in a popup. Default `startcmd` is `cccc` (an alias
for `claude --dangerously-skip-permissions -c` — change it per-project if you'd
rather not).

### `pj here` — keep the session you're in

```
pj here auth-api
│  │    └── the name YOU pick → tmux session name + how you return (pj auth-api)
│  └── "use the session I'm in right now" (reads host = this box, dir = current path)
└── the command
```

Omit the name (`pj here`) to keep the session's current name.

---

## 🌐 The fleet (cross-host)

```
                          pj <project>           ← one command, any host
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
        ┌──────────┐         ssh -t      ┌──────────┐
        │  laptop  │  ◀──── (tailnet) ───▶│  server  │
        │   tmux   │                     │   tmux   │
        └──────────┘                     └──────────┘
        projects here:                   projects here:
        ● auth-api                       ● daily-scrape
        ● infra-tf                       ○ payments-svc
```

Each machine owns its own projects. `pj` reads every host's registry + live
`tmux ls` over SSH (parallel, cached ~5s, short timeout so an unreachable peer
*can't hang the picker*) and presents the **union**.

- **Local target** → `switch-client` if you're in tmux, else `attach`.
- **Remote target** → `ssh -t <host> proj-attach <name>`; detach with
  `Ctrl-b d` and you're back where you started.

The fleet is defined by [`peers`](peers.example) — one short hostname
(`hostname -s`) per line, each host skips itself, so the same file works
everywhere. Requires passwordless SSH between fleet hosts. Empty peers =
single-host mode.

> ⚠️ **Jumping cross-host while already inside tmux is *nested*** (a remote
> tmux drawn inside your local pane — there's no way to switch a client across
> servers). `proj` detects this and tells you: drive the inner session with
> **`Ctrl-b Ctrl-b <key>`** (double prefix), and return with **`Ctrl-b Ctrl-b d`**.
> A plain `Ctrl-b d` detaches your *local* box.

---

## 🔌 Detach. Walk away. Come back.

```
  you in tmux              somewhere else            you, later
  ───────────              ──────────────            ──────────
  $ pj auth-api      ──▶   (close laptop)     ──▶   $ pj auth-api
  ▶ agent working          (agent keeps              ▶ agent done,
                            running on host)            output waiting
```

`Ctrl-b d` to detach. Closing the window or dropping SSH does the same — none
of it kills the session. Detach is **not pause**: a mid-task agent keeps going;
an idle one keeps waiting.

---

## ♻️ Survives reboots

On Linux the installer enables a `systemd --user` service, `tmux-projects`,
that re-creates this host's sessions at boot and re-runs each one's `startcmd`.
With the default `cccc`, Claude Code resumes the last conversation in that
directory. **User lingering** is enabled so the service runs without you logging
in.

> ⚠️ Default `cccc` means a freshly-booted unattended box auto-launches Claude
> with `--dangerously-skip-permissions` — no prompts. Set a tamer startcmd
> (`claude --continue`, or blank for a plain shell) per project in
> `projects.tsv` if that worries you.

The in-memory state of a process can't be snapshotted. What *does* survive: the
session layout + working dir (recreated) and the Claude conversation (resumed
from disk).

---

## 🚪 What if I'm NOT in tmux when I run `pj`?

`pj <name>` handles every case cleanly:

| Where you are | What happens |
|---|---|
| Inside tmux | `switch-client` (no nesting) |
| Plain terminal, not in tmux | Attaches you (the normal path) |
| No terminal at all (script, pipe) | Ensures the session exists, tells you `Open it from an interactive shell with: pj <name>` |
| `pj here` with no tmux | Tells you exactly how to start one |

No more cryptic `open terminal failed` errors.

---

## 📒 The registry

A simple TSV, one project per row:

```
name <TAB> host <TAB> dir <TAB> startcmd
```

Example:
```
auth-api    laptop    /home/me/work/auth-api    cccc
```

- **Gitignored** — each machine keeps its own untracked copy, seeded from
  [`projects.tsv.example`](projects.tsv.example). Edit by hand (real tabs) or
  via `pj add` / `pj here`.
- A host only acts on rows where `host` matches its own `hostname -s`; foreign
  rows are ignored locally and reported by the host that owns them.
- Names with `.` or `:` work (e.g. `acme.com`) — tmux can't put those characters
  in a session name (they're target separators), so the tmux session is named
  with them mapped to `_` (`acme.com` → session `acme_com`). You always type the
  real name; the mapping is internal.

---

## 🛠️ How it works

| File | Role |
|---|---|
| [`bin/proj`](bin/proj) | The CLI: picker, fleet-aware jump, `ls`, `here`, `add`, `rm` |
| [`bin/proj-attach`](bin/proj-attach) | (per host) ensure session, then `switch-client` / `attach` / guide |
| [`bin/proj-status`](bin/proj-status) | Fleet status (local + peers over SSH, parallel, cached) |
| [`bin/proj-boot`](bin/proj-boot) | Boot-time session rebuild, run by the systemd service |
| [`bin/proj-completion.bash`](bin/proj-completion.bash) | Bash tab-completion for `pj` |
| [`tmux.conf`](tmux.conf) | Loud project name in the status bar + popup picker keybind |
| [`systemd/tmux-projects.service`](systemd/tmux-projects.service) | User service running `proj-boot` at boot |
| [`install.sh`](install.sh) | The idempotent installer |
| [`commands/keep.md`](commands/keep.md) | The `/keep` Claude Code slash command |

The orange block at the left of the tmux status bar always shows the **current
session name**, big and bold — so you stop acting in the wrong one.

---

## 🗺️ Roadmap

- 🍎 macOS boot service (launchd) — installer currently warns on Darwin
- 🔄 Optional shared registry (git-backed) instead of each host owning its own
- 🪟 Bash completion for cross-host project names without warming the cache

---

## 🧯 Troubleshooting

- **`pj: command not found`** → `exec $SHELL` or `source ~/.bashrc`
- **Picker doesn't show another host's projects** → add it to `peers` on both
  boxes and confirm passwordless SSH works *both* directions (`ssh <host> hostname`)
- **`proj here: you're not inside tmux`** → `echo $TMUX` is empty; start under tmux
- **Picker is empty** → no projects registered for this host yet; use `pj add`/`pj here`
- **Boot sessions didn't return** → `systemctl --user status tmux-projects` and
  `loginctl show-user "$USER" | grep Linger=yes`
- **Started ssh on a remote project, can't detach back** → you're in the *nested*
  case; use `Ctrl-b Ctrl-b d`

---

<div align="center">

**Now go close your laptop.**

The session will be waiting.

</div>
