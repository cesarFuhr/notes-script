SUBJECT="personal"
if [ -n "$1" ]; then
  SUBJECT=$1
fi

pushd ~/.notes/"$SUBJECT" > /dev/null && \
  rg --pretty '\[ \]' . && \
  popd > /dev/null || return
