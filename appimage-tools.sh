# desktop-file-validate

# Build the latest version of NSIS (Linux) in docker container
cidFile="/tmp/desktop-file-validate-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

cd "$BASEDIR"
docker run --cidfile="$cidFile" buildpack-deps:xenial bash -c \
'mkdir -p /tmp/desktop-file-validate && curl -L http://prdownloads.sourceforge.net/scons/scons-local-2.5.1.tar.gz | tar -xz -C /tmp/scons &&
 mkdir -p /tmp/nsis && curl -L https://sourceforge.net/projects/nsis/files/NSIS%203/3.04/nsis-3.04-src.tar.bz2/download | tar -xj -C /tmp/nsis --strip-components 1 &&
 cd /tmp/nsis &&
 python /tmp/scons/scons.py STRIP=0 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_CONST_DATA_PATH=no NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 makensis
 '

containerId=$(cat "$cidFile")
mkdir $OUTPUT_DIR/linux
docker cp "$containerId":/usr/bin/desktop-file-validate $OUTPUT_DIR/linux/makensis
docker rm "$containerId"
unlink "$cidFile"
