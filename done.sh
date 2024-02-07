SUBJECT="personal"
if [ -n "$1" ]; then
  SUBJECT=$1
fi

mkdir -p ~/.notes/$SUBJECT && pushd $_ > /dev/null 

rg --pretty '\[x\]' .

popd > /dev/null
