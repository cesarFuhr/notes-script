SUBJECT="."
if [ -n "$1" ]; then
  SUBJECT=$1
fi

NOTE_NAME=$(date +"%Y-%m-%d-%H:%M:%S")
if [ -n "$2" ]; then
  NOTE_NAME=$2
fi

if [ -z "${NOTES_ROOT}" ]; then
  NOTES_ROOT="$HOME/.notes"
fi

FILE="$NOTE_NAME.md"

mkdir -p "$NOTES_ROOT/$SUBJECT" && pushd "$_" > /dev/null || return

$EDITOR "$NOTES_ROOT/$SUBJECT/${FILE}"

popd > /dev/null || exit
