#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_PATH/../init.sh"
cd "$REVAMB_TOOLS"

mkdir -p common
pushd common >& /dev/null

if [ ! -e "$INSTALL_PATH/lib/libboost_unit_test_framework.so" ]; then

    echo "Building Boost"

    BINUTILS_ARCHIVE="boost_1_63_0.tar.bz2"
    [ ! -e "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE" ] && wget "https://sourceforge.net/projects/boost/files/boost/1.63.0/$BINUTILS_ARCHIVE" -O "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"

    mkdir -p boost
    pushd boost >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"
    cd boost_1_63_0/

    ./bootstrap.sh --prefix="$INSTALL_PATH" --with-libraries=test

    ./b2 install

    popd >& /dev/null

fi

popd >& /dev/null
