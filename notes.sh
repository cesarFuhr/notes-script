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
EOF
}

is_command() {
  case "$1" in
    new | today | yesterday | tomorrow | journal | todo | search | find) return 0 ;;
    ????-??-??) return 0 ;;
    *) return 1 ;;
  esac
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
  *)
    usage >&2
    exit 2
    ;;
esac
