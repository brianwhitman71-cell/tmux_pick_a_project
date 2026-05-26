# bash completion for proj / pj. Source from ~/.bashrc:
#   source ~/Projects/tmux/bin/proj-completion.bash
_PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_proj_complete() {
  local cur subs names reg cache
  cur="${COMP_WORDS[COMP_CWORD]}"
  subs="ls here add rm help"
  reg="$_PROJ_DIR/projects.tsv"
  cache="/tmp/proj-status-$(id -u).cache"   # warm cache may include remote projects

  names=""
  [ -f "$reg" ]   && names+=" $(awk -F'\t' '$1!~/^#/ && NF{print $1}' "$reg" 2>/dev/null)"
  [ -f "$cache" ] && names+=" $(cut -f1 "$cache" 2>/dev/null)"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$subs $names" -- "$cur") )
  fi
}
complete -F _proj_complete proj pj
