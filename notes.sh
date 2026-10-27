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
  notes conflicts
EOF
}

is_command() {
  case "$1" in
    new | today | yesterday | tomorrow | journal | todo | search | find | sync | conflicts) return 0 ;;
    ????-??-??) return 0 ;;
    *) return 1 ;;
  esac
}

git_notes() {
  GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o BatchMode=yes -o ConnectTimeout=3"} \
    git -C "$NOTES_ROOT" "$@"
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

notify() {
  printf 'notes: %s\n' "$1" >&2
  if command -v notify-send >/dev/null; then
    notify-send --app-name=notes notes "$1" 2>/dev/null || true
  fi
}

conflict_copy() {
  local path=$1
  if [[ ${path##*/} == ?*.* ]]; then
    printf '%s.conflict-%s.%s' "${path%.*}" "$(uname -n)" "${path##*.}"
  else
    printf '%s.conflict-%s' "$path" "$(uname -n)"
  fi
}

# Commits an unresolved merge as-is so syncing never blocks: text files keep
# git's conflict markers, binary files take the remote version and keep the
# local one beside it.
commit_conflicts() {
  local path
  local -a paths
  mapfile -d '' paths < <(git_notes diff --name-only --diff-filter=U -z)
  (( ${#paths[@]} > 0 )) || return 1
  for path in "${paths[@]}"; do
    if git_notes cat-file -e ":2:$path" 2>/dev/null && git_notes cat-file -e ":3:$path" 2>/dev/null \
      && ! grep -q '^<<<<<<< ' "$NOTES_ROOT/$path" 2>/dev/null; then
      git_notes show ":2:$path" >"$NOTES_ROOT/$(conflict_copy "$path")"
      git_notes checkout --theirs -- "$path"
    elif [[ -f $NOTES_ROOT/$path ]]; then
      sed -i "s/^<<<<<<< HEAD\$/<<<<<<< $(uname -n)/" "$NOTES_ROOT/$path"
    fi
  done
  git_notes add --all || return 1
  git_notes commit --quiet --no-gpg-sign --message "notes: $(uname -n) merge with conflicts" || return 1
  notify "sync conflict in ${paths[*]}; run notes conflicts"
}

pull_notes() {
  git_notes remote get-url origin &>/dev/null || return 0
  if ! git_notes fetch --quiet origin &>/dev/null; then
    printf 'notes: pull failed, continuing offline\n' >&2
    return 1
  fi
  local upstream
  upstream=$(git_notes rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || return 0
  git_notes rebase --quiet "$upstream" &>/dev/null && return 0
  git_notes rebase --abort &>/dev/null || true
  git_notes merge --quiet --no-edit --no-gpg-sign "$upstream" &>/dev/null && return 0
  commit_conflicts
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
  if [[ -n $line ]]; then
    (cd "$NOTES_ROOT" && "${editor[@]}" "+$line" "$file")
  else
    (cd "$NOTES_ROOT" && "${editor[@]}" "$file")
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
    git_notes rev-parse --is-inside-work-tree &>/dev/null || { printf 'notes: %s is not a git repository\n' "$NOTES_ROOT" >&2; exit 1; }
    with_lock sync_notes
    ;;
  conflicts)
    (( $# == 0 )) || { usage >&2; exit 2; }
    [[ -d $NOTES_ROOT ]] || exit 0
    # One "path<TAB>line:text" entry per marker or conflict copy; paths may contain colons.
    conflicts=$(
      cd "$NOTES_ROOT" && {
        rg --null --line-number --no-heading --glob '!.git' '^<<<<<<< ' . | tr '\0' '\t' || true
        find . -path ./.git -prune -o -type f -name '*.conflict-*' -printf '%p\t1:\n'
      }
    )
    [[ -n $conflicts ]] || { printf 'notes: no conflicts\n'; exit 0; }
    selected=$(fzf <<<"$conflicts") || exit 0
    file=${selected%%$'\t'*}
    match=${selected#*$'\t'}
    open_file "$NOTES_ROOT/${file#./}" "${match%%:*}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
