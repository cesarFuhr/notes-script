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
  notes sync [--status]
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
    (
      flock -w 30 9 || { printf 'notes: another sync is still running\n' >&2; exit 1; }
      "$@"
    ) 9>"$lock"
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
  (( ${#paths[@]} > 0 )) || { printf 'notes: merge failed without conflicts\n' >&2; return 1; }
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
  local err
  if ! err=$(git_notes fetch --quiet origin 2>&1); then
    err=$(grep -v -e '^$' -e '^Please make sure' -e '^and the repository exists' <<<"$err" | paste -sd ' ')
    printf 'notes: fetch failed, continuing offline: %s\n' "$err" >&2
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

# One "path<TAB>line:text" entry per marker or conflict copy; paths may contain colons.
list_conflicts() {
  cd "$NOTES_ROOT" && {
    rg --null --line-number --no-heading --glob '!.git' '^<<<<<<< ' . | tr '\0' '\t' || true
    find . -path ./.git -prune -o -type f -name '*.conflict-*' -printf '%p\t1:\n'
  }
}

ago() {
  local seconds=$(( $(date +%s) - $1 ))
  if (( seconds < 60 )); then
    printf '%ds ago' "$seconds"
  elif (( seconds < 3600 )); then
    printf '%dm ago' $(( seconds / 60 ))
  elif (( seconds < 86400 )); then
    printf '%dh ago' $(( seconds / 3600 ))
  else
    printf '%dd ago' $(( seconds / 86400 ))
  fi
}

# Reports sync state from local data only, so it is instant and works offline.
sync_status() {
  local git_dir upstream counts ahead behind changed files timers started next last result
  git_dir=$(git_notes rev-parse --absolute-git-dir)

  printf '%-12s %s\n' repository "$NOTES_ROOT"
  printf '%-12s %s\n' remote "$(git_notes remote get-url origin 2>/dev/null || echo none)"

  changed=$(git_notes status --porcelain | wc -l)
  printf '%-12s %s\n' uncommitted "$changed file(s)"

  if upstream=$(git_notes rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
    counts=$(git_notes rev-list --left-right --count "HEAD...$upstream")
    read -r ahead behind <<<"$counts"
    printf '%-12s %s\n' unpushed "$ahead commit(s)"
    printf '%-12s %s\n' behind "$behind commit(s) as of last fetch"
  else
    printf '%-12s %s\n' upstream none
  fi

  if [[ -f $git_dir/FETCH_HEAD ]]; then
    printf '%-12s %s\n' 'last fetch' "$(ago "$(stat -c %Y "$git_dir/FETCH_HEAD")")"
  else
    printf '%-12s %s\n' 'last fetch' never
  fi
  if git_notes rev-parse --verify --quiet HEAD >/dev/null; then
    printf '%-12s %s\n' 'last commit' "$(ago "$(git_notes log -1 --format=%ct)") ($(git_notes log -1 --format=%s))"
  fi

  files=$(list_conflicts | cut -f1 | sort -u | wc -l)
  if (( files > 0 )); then
    printf '%-12s %s\n' conflicts "$files file(s), run notes conflicts"
  else
    printf '%-12s %s\n' conflicts none
  fi

  if command -v systemctl >/dev/null; then
    timers=$(systemctl --user list-timers notes-sync.timer --output=json 2>/dev/null || true)
    if [[ $(systemctl --user show notes-sync.service --property=ActiveState --value 2>/dev/null) == activating ]]; then
      started=$(systemctl --user show notes-sync.service --property=InactiveExitTimestamp --value --timestamp=unix)
      started=${started#@}
      printf '%-12s %s\n' timer "sync running now, started $(ago "$started")"
    elif [[ $timers =~ \"next\":([0-9]+).*\"last\":([0-9]+) ]]; then
      next=$(( BASH_REMATCH[1] / 1000000 - $(date +%s) ))
      last=$(( BASH_REMATCH[2] / 1000000 ))
      result=$(systemctl --user show notes-sync.service --property=Result --value)
      printf '%-12s %s\n' timer "last run $(ago "$last") ($result), next in $(( next / 60 ))m$(( next % 60 ))s"
    else
      printf '%-12s %s\n' timer 'not running'
    fi
  fi

  if command -v journalctl >/dev/null; then
    local failures count id
    failures=$(journalctl --user --unit=notes-sync.service --since=-24h --output=json \
      --output-fields=MESSAGE,USER_INVOCATION_ID --no-pager 2>/dev/null | grep 'Failed with result' || true)
    count=$(grep -c . <<<"$failures" || true)
    if (( count == 0 )); then
      printf '%-12s %s\n' failures 'none in the last 24h'
    elif [[ ${failures##*$'\n'} =~ \"USER_INVOCATION_ID\":\"([0-9a-f]+)\" ]]; then
      id=${BASH_REMATCH[1]}
      [[ ${failures##*$'\n'} =~ \"__REALTIME_TIMESTAMP\":\"([0-9]+)\" ]]
      printf '%-12s %s\n' failures "$count in the last 24h, latest $(ago $(( BASH_REMATCH[1] / 1000000 ))):"
      journalctl --user "_SYSTEMD_INVOCATION_ID=$id" --output=cat --no-pager 2>/dev/null \
        | grep . | sed 's/^/             /' || printf '             (no output)\n'
    fi
  fi
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
    (( $# == 0 )) || [[ $# == 1 && $1 == --status ]] || { usage >&2; exit 2; }
    git_notes rev-parse --is-inside-work-tree &>/dev/null || { printf 'notes: %s is not a git repository\n' "$NOTES_ROOT" >&2; exit 1; }
    if (( $# == 1 )); then
      sync_status
    else
      with_lock sync_notes
    fi
    ;;
  conflicts)
    (( $# == 0 )) || { usage >&2; exit 2; }
    [[ -d $NOTES_ROOT ]] || exit 0
    conflicts=$(list_conflicts)
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
