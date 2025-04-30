#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/out/linux-tools
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

TMP_DIR=/tmp/linux-tools
rm -rf $TMP_DIR
mkdir -p $TMP_DIR/Cellar $TMP_DIR/bin $TMP_DIR/opt

# brew install gettext glib gnu-tar libffi libgsf libtool lzip makedepend openssl osslsigncode pcre

CELLAR_PACKAGES=gettext,glib,gnu-tar,libffi,libgsf,libtool,lzip,makedepend,openssl,osslsigncode,pcre
BIN_PACKAGES=brew,gapplication,gdbus,gdbus-codegen,gio,gio-querymodules,glib-compile-resources,glib-compile-schemas,glib-genmarshal,glib-gettextize,glib-mkenums,glibtool,glibtoolize,gobject-query,gresource,gsettings,gsf,gsf-office-thumbnailer,gsf-vba-dump,gtar,gtester,gtester-report,lzip,makedepend,osslsigncode,pcre-config,pcregrep,pcretest
OPT_PACKAGES=gettext,glib,gnu-tar,libffi,libgsf,libtool,lzip,makedepend,openssl,openssl@1.0,osslsigncode,pcre,pcre1

BREW_LOCATION=$(brew --prefix)
cp -a "$BREW_LOCATION/Cellar/{$CELLAR_PACKAGES}" $TMP_DIR/Cellar/
cp -a "$BREW_LOCATION/bin/{$BIN_PACKAGES}" $TMP_DIR/bin/
cp -a "$BREW_LOCATION/opt/{$OPT_PACKAGES}" $TMP_DIR/opt

cp -a $TMP_DIR/* $OUTPUT_DIR
rm -rf $TMP_DIR