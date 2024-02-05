SUBJECT="personal"
if [ -n "$1" ]; then
  SUBJECT=$1
fi

CUR_DIR=$PWD
FOLDER=$(date +"%Y/%m")
FILE=$(date +"%d")

mkdir -p ~/.notes/$SUBJECT && cd $_ && mkdir -p $FOLDER

$EDITOR "./$FOLDER/$FILE.md"

cd $CUR_DIR
