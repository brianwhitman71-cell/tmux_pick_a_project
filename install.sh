#!/usr/bin/env bash
# install.sh — idempotent installer for the proj tmux switcher.
# Linux: installs a systemd --user service. macOS: launchd (deferred, warns).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
host="$(hostname -s)"
echo "== installing proj on $host ($OS) from $REPO =="

# --- deps -----------------------------------------------------------------
miss=0
for c in tmux fzf; do
  command -v "$c" >/dev/null 2>&1 || { echo "MISSING required dep: $c" >&2; miss=1; }
done
command -v claude >/dev/null 2>&1 || \
  echo "WARN: 'claude' not on non-interactive PATH (boot launch uses the interactive shell, so usually fine)" >&2
[ "$miss" = 0 ] || { echo "aborting: install required deps above first" >&2; exit 1; }

chmod +x "$REPO"/bin/*

# seed this host's registry from the example on first install (it's gitignored,
# so each machine keeps its own untracked copy)
if [ ! -f "$REPO/projects.tsv" ]; then
  cp "$REPO/projects.tsv.example" "$REPO/projects.tsv"
  echo "created projects.tsv from example (edit it, or use: proj add / proj here)"
fi

# --- tmux.conf ------------------------------------------------------------
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
  echo "WARN: ~/.tmux.conf exists and isn't our symlink; leaving it." >&2
  echo "      add this line to it:  source-file $REPO/tmux.conf" >&2
else
  ln -sfn "$REPO/tmux.conf" "$HOME/.tmux.conf"
  echo "linked ~/.tmux.conf -> $REPO/tmux.conf"
fi

# --- .bashrc block (append-only, marker-guarded) --------------------------
MARK="# >>> proj (tmux project switcher) >>>"
if grep -qF "$MARK" "$HOME/.bashrc" 2>/dev/null; then
  echo "~/.bashrc already has the proj block"
else
  cat >>"$HOME/.bashrc" <<EOF

$MARK
export PATH="\$PATH:$REPO/bin"
alias pj=proj
# auto-pick a project on interactive SSH login when not already in tmux
if [[ \$- == *i* && -n \${SSH_CONNECTION:-} && -z \${TMUX:-} && -z \${PROJ_NO_AUTOPICK:-} ]]; then
  proj
fi
# <<< proj <<<
EOF
  echo "added proj block to ~/.bashrc (PATH + alias pj + SSH auto-pick)"
fi

# --- boot service ---------------------------------------------------------
if [ "$OS" = "Linux" ]; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO/systemd/tmux-projects.service" "$HOME/.config/systemd/user/"
  if ! loginctl show-user "$USER" 2>/dev/null | grep -q 'Linger=yes'; then
    echo "enabling linger so sessions survive reboot without login..."
    loginctl enable-linger "$USER" 2>/dev/null \
      || sudo loginctl enable-linger "$USER" 2>/dev/null \
      || echo "WARN: could not enable linger; run:  sudo loginctl enable-linger $USER" >&2
  fi
  systemctl --user daemon-reload
  systemctl --user enable --now tmux-projects.service
  echo "systemd --user service tmux-projects enabled and started"
elif [ "$OS" = "Darwin" ]; then
  echo "macOS: launchd boot service not implemented yet (deferred). proj CLI still works."
fi

echo "== done. open a new shell (or: source ~/.bashrc), then run 'p' =="
