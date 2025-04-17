brew install libgsf
brew install osslsigncode

BASEDIR=$(cd "$(dirname "$0")/../.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/out/winCodeSign/darwin
mkdir -p $OUTPUT_DIR

cp /opt/homebrew/bin/osslsigncode $OUTPUT_DIR/