#!/usr/bin/env bash

set -euo pipefail

NOTES_ROOT=${NOTES_ROOT:-"$HOME/.notes"}
SPACE=${NOTES_SPACE:-personal}
COMMAND=today

usage() {
  cat <<'EOF'
Usage:
  notes [space]
  notes [space] new
  notes [space] today|yesterday|tomorrow
  notes [space] journal YYYY-MM-DD
  notes [space] YYYY-MM-DD
  notes [space] todo
  notes [space] search QUERY
  notes [space] find [QUERY]
  notes sync
EOF
}

is_command() {
  case "$1" in
    new | today | yesterday | tomorrow | journal | todo | search | find | sync) return 0 ;;
    ????-??-??) return 0 ;;
    *) return 1 ;;
  esac
}

git_notes() {
  GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o BatchMode=yes -o ConnectTimeout=5"} \
    git -C "$NOTES_ROOT" "$@"
}

sync_enabled() {
  [[ ${NOTES_SYNC:-1} != 0 ]] && command -v git >/dev/null && git_notes rev-parse --is-inside-work-tree &>/dev/null
}

# Serializes syncs between the editor wrapper and the timer.
with_lock() {
  local lock
  lock=$(git_notes rev-parse --absolute-git-dir)/notes-sync.lock
  if command -v flock >/dev/null; then
    (flock -w 30 9 && "$@") 9>"$lock"
  else
    "$@"
  fi
}

pull_notes() {
  git_notes remote get-url origin &>/dev/null || return 0
  local git_dir
  git_dir=$(git_notes rev-parse --absolute-git-dir)
  if ! git_notes pull --quiet --rebase --autostash &>/dev/null; then
    if [[ -d $git_dir/rebase-merge || -d $git_dir/rebase-apply ]]; then
      git_notes rebase --abort 2>/dev/null || true
      printf 'notes: sync conflict, local commits kept; resolve in %s\n' "$NOTES_ROOT" >&2
    else
      printf 'notes: pull failed, continuing offline\n' >&2
    fi
    return 1
  fi
}

commit_notes() {
  git_notes add --all || return 1
  git_notes diff --cached --quiet && return 0
  git_notes commit --quiet --no-gpg-sign --message "notes: $(uname -n) $(date '+%F %T')"
}

push_notes() {
  git_notes remote get-url origin &>/dev/null || return 0
  git_notes push --quiet || printf 'notes: push failed, will retry on next sync\n' >&2
}

sync_notes() {
  commit_notes && pull_notes && push_notes
}

open_file() {
  local file=$1
  local line=${2:-}
  local -a editor

  mkdir -p "$(dirname "$file")"
  read -r -a editor <<<"${EDITOR:-vi}"
  if sync_enabled; then
    with_lock pull_notes || true
  fi
  if [[ -n $line ]]; then
    (cd "$NOTES_ROOT" && "${editor[@]}" "+$line" "$file")
  else
    (cd "$NOTES_ROOT" && "${editor[@]}" "$file")
  fi
  if sync_enabled; then
    with_lock sync_notes || true
  fi
}

open_journal() {
  local date=$1

  if [[ ! $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || [[ $(date -d "$date" +%F 2>/dev/null) != "$date" ]]; then
    printf 'notes: invalid date: %s\n' "$date" >&2
    exit 2
  fi

  open_file "$SPACE_ROOT/journal/$date.md"
}

if (( $# > 0 )); then
  if is_command "$1"; then
    COMMAND=$1
    shift
  else
    SPACE=$1
    shift
    if (( $# > 0 )); then
      COMMAND=$1
      shift
    fi
  fi
fi

SPACE_ROOT="$NOTES_ROOT/$SPACE"

case "$COMMAND" in
  new)
    (( $# == 0 )) || { usage >&2; exit 2; }
    open_file "$SPACE_ROOT/inbox/$(date +%Y-%m-%d-%H%M%S).md"
    ;;
  today)
    (( $# == 0 )) || { usage >&2; exit 2; }
    open_journal "$(date +%F)"
    ;;
  yesterday | tomorrow)
    (( $# == 0 )) || { usage >&2; exit 2; }
    open_journal "$(date -d "$COMMAND" +%F)"
    ;;
  journal)
    (( $# == 1 )) || { usage >&2; exit 2; }
    open_journal "$1"
    ;;
  ????-??-??)
    (( $# == 0 )) || { usage >&2; exit 2; }
    open_journal "$COMMAND"
    ;;
  todo)
    (( $# == 0 )) || { usage >&2; exit 2; }
    [[ -d $SPACE_ROOT ]] || exit 0
    rg --pretty --line-number '\[ \]' "$SPACE_ROOT"
    ;;
  search)
    (( $# > 0 )) || { usage >&2; exit 2; }
    [[ -d $SPACE_ROOT ]] || exit 0
    mapfile -d '' files < <(find "$SPACE_ROOT" -type f \( -name '*.md' -o -name '*.txt' -o -name '*.sql' \) -print0)
    (( ${#files[@]} > 0 )) || exit 0
    selected=$(agrep -2 -k -n -H -- "$*" "${files[@]}" | fzf) || exit 0
    file=${selected%%:*}
    match=${selected#*:}
    line=${match%%:*}
    open_file "$file" "$line"
    ;;
  find)
    [[ -d $SPACE_ROOT ]] || exit 0
    command -v fzf >/dev/null || { printf 'notes: find requires fzf\n' >&2; exit 1; }
    selected=$(cd "$SPACE_ROOT" && find . -type f -print | sort | fzf --query "$*") || exit 0
    [[ -n $selected ]] && open_file "$SPACE_ROOT/${selected#./}"
    ;;
  sync)
    (( $# == 0 )) || { usage >&2; exit 2; }
    [[ ${NOTES_SYNC:-1} != 0 ]] || { printf 'notes: sync disabled by NOTES_SYNC=0\n' >&2; exit 1; }
    sync_enabled || { printf 'notes: %s is not a git repository\n' "$NOTES_ROOT" >&2; exit 1; }
    with_lock sync_notes
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
