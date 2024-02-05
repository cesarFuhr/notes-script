SUBJECT="personal"
if [ -n "$1" ]; then
  SUBJECT=$1
fi

NOTES_DIR=$(date +"%Y/%m")
FILE=$(date +"%d")

mkdir -p ~/.notes/$SUBJECT && pushd $_ && mkdir -p $NOTES_DIR

$EDITOR "./${NOTES_DIR}/${FILE}.md"

popd
