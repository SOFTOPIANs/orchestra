#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_PATH/../init.sh"
cd "$REVAMB_TOOLS"

mkdir -p mips
pushd mips >& /dev/null

if [ ! -e "$INSTALL_PATH/usr/mips-unknown-linux-musl/bin/ld" ]; then

    echo "Building MIPS binutils"

    BINUTILS_ARCHIVE="binutils-2.25.1.tar.bz2"
    [ ! -e "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/binutils/$BINUTILS_ARCHIVE" -O "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"

    mkdir -p binutils/build
    pushd binutils >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"
    cd build/

    ../binutils-*/configure \
        --build=x86_64-pc-linux-gnu \
        --host=x86_64-pc-linux-gnu \
        --target=mips-unknown-linux-musl \
        --prefix=$INSTALL_PATH/usr \
        --with-sysroot=$INSTALL_PATH/usr/mips-unknown-linux-musl \
        --datadir=$INSTALL_PATH/usr/share/binutils-data/mips-unknown-linux-musl/2.25.1 \
        --infodir=$INSTALL_PATH/usr/share/binutils-data/mips-unknown-linux-musl/2.25.1/info \
        --mandir=$INSTALL_PATH/usr/share/binutils-data/mips-unknown-linux-musl/2.25.1/man \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/binutils-bin/2.25.1 \
        --libdir=$INSTALL_PATH/usr/lib64/binutils/mips-unknown-linux-musl/2.25.1 \
        --libexecdir=$INSTALL_PATH/usr/lib64/binutils/mips-unknown-linux-musl/2.25.1 \
        --includedir=$INSTALL_PATH/usr/lib64/binutils/mips-unknown-linux-musl/2.25.1/include \
        --without-included-gettext \
        --with-zlib \
        --enable-poison-system-directories \
        --enable-secureplt \
        --enable-obsolete \
        --disable-shared \
        --enable-threads \
        --enable-install-libiberty \
        --disable-werror \
        --disable-static \
        --disable-gdb \
        --disable-libdecnumber \
        --disable-readline \
        --disable-sim \
        --without-stage1-ldflags

    make -j"$JOBS"
    make install

    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/mips-unknown-linux-musl/usr/include/stdio.h" ]; then

    echo "Installing MIPS musl headers"

    MUSL_ARCHIVE=musl-1.1.12.tar.gz
    [ ! -e "$DOWNLOAD_PATH/$MUSL_ARCHIVE" ] && wget "http://www.musl-libc.org/releases/$MUSL_ARCHIVE" -O "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    BUILD_DIR=musl/build-headers
    mkdir -p "$BUILD_DIR"
    pushd "$BUILD_DIR" >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    cd musl-*
    CC=true ../musl-*/configure \
        --target=mips-unknown-linux-musl \
        --prefix="$INSTALL_PATH/usr/mips-unknown-linux-musl/usr" \
        --syslibdir="$INSTALL_PATH/usr/mips-unknown-linux-musl/lib" \
        --disable-gcc-wrapper

    make include/bits/alltypes.h
    make install-headers

    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/mips-unknown-linux-musl/usr/include/asm/unistd.h" ]; then
    LINUX_ARCHIVE=linux-4.5.2.tar.xz
    [ ! -e "$DOWNLOAD_PATH/$LINUX_ARCHIVE" ] && wget "https://cdn.kernel.org/pub/linux/kernel/v4.x/$LINUX_ARCHIVE" -O "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    mkdir -p linux-headers
    pushd linux-headers >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    cd linux-*
    make ARCH=mips INSTALL_HDR_PATH="$INSTALL_PATH/usr/mips-unknown-linux-musl/usr" headers_install

    popd >& /dev/null
fi

NEW_GCC="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/gcc-bin/5.3.0/mips-unknown-linux-musl-gcc"
GCC_CONFIGURE=$(echo --host=x86_64-pc-linux-gnu \
        --build=x86_64-pc-linux-gnu \
        --target=mips-unknown-linux-musl \
        --prefix=$INSTALL_PATH/usr \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/gcc-bin/5.3.0 \
        --includedir=$INSTALL_PATH/usr/lib/gcc/mips-unknown-linux-musl/5.3.0/include \
        --datadir=$INSTALL_PATH/usr/share/gcc-data/mips-unknown-linux-musl/5.3.0 \
        --mandir=$INSTALL_PATH/usr/share/gcc-data/mips-unknown-linux-musl/5.3.0/man \
        --infodir=$INSTALL_PATH/usr/share/gcc-data/mips-unknown-linux-musl/5.3.0/info \
        --with-gxx-include-dir=$INSTALL_PATH/usr/lib/gcc/mips-unknown-linux-musl/5.3.0/include/g++-v5 \
        --with-python-dir=/share/gcc-data/mips-unknown-linux-musl/5.3.0/python \
        --with-sysroot=$INSTALL_PATH/usr/mips-unknown-linux-musl \
        --enable-obsolete \
        --enable-secureplt \
        --disable-werror \
        --with-system-zlib \
        --enable-nls \
        --without-included-gettext \
        --enable-checking=release \
        --enable-libstdcxx-time \
        --enable-poison-system-directories \
        --disable-shared \
        --disable-libatomic \
        --disable-bootstrap \
        --disable-multilib \
        --disable-altivec \
        --disable-fixed-point \
        --with-abi= \
        --disable-libgcj \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libssp \
        --disable-libcilkrts \
        --disable-libmpx \
        --disable-vtable-verify \
        --disable-libvtv \
        --disable-libquadmath \
        --enable-lto \
        --without-isl \
        --disable-libsanitizer)

if [ ! -e "$NEW_GCC" ]; then

    echo "Building MIPS gcc"

    GCC_ARCHIVE="gcc-5.3.0.tar.gz"
    [ ! -e "$DOWNLOAD_PATH/$GCC_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/gcc/gcc-5.3.0/$GCC_ARCHIVE" -O "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    mkdir -p gcc/build
    pushd gcc >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    pushd gcc-*/
      patch -p1 < "$SCRIPT_PATH/cfns-fix-mismatch-in-gnu_inline-attributes.patch"
    popd

    cd build

    ../gcc-*/configure \
        --enable-languages=c \
        $GCC_CONFIGURE

    make -j"$JOBS"
    make install

    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/mips-unknown-linux-musl/usr/lib/libc.a" ]; then

    MUSL_ARCHIVE=musl-1.1.12.tar.gz
    [ ! -e "$MUSL_ARCHIVE" ] && wget "http://www.musl-libc.org/releases/$MUSL_ARCHIVE" -O "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    for CONFIG in ${CONFIGS[@]}; do

        FLAGS_NAME="CFLAGS_$CONFIG"
        FLAGS="${!FLAGS_NAME}"
        echo "Building MIPS musl $CONFIG"

        BUILD_DIR="musl/build-$CONFIG"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
        pushd "$BUILD_DIR" >& /dev/null
        tar xaf "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

        cd musl-*
        patch -p1 < "$SCRIPT_PATH/musl-printf-floating-point-rounding.patch"
        CC="$NEW_GCC" \
          CFLAGS="$FLAGS" \
          ../musl-*/configure \
          --target=mips-unknown-linux-musl \
          --prefix="$INSTALL_PATH/usr/mips-unknown-linux-musl/usr" \
          --syslibdir="$INSTALL_PATH/usr/mips-unknown-linux-musl/lib" \
          --disable-gcc-wrapper

        make -j"$JOBS"

        popd >& /dev/null

    done

fi

CHOSEN_CONFIG="${CHOSEN_CONFIG:-default}"
if [ -e "musl/build-$CHOSEN_CONFIG" ]; then

    echo "Installing MIPS musl $CHOSEN_CONFIG"
    pushd "musl/build-$CHOSEN_CONFIG" >& /dev/null
    cd musl-*
    make install
    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/gcc-bin/5.3.0/mips-unknown-linux-musl-g++" ]; then

    echo "Building MIPS g++"

    GCC_ARCHIVE="gcc-5.3.0.tar.gz"
    [ ! -e "$DOWNLOAD_PATH/$GCC_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/gcc/gcc-5.3.0/$GCC_ARCHIVE" -O "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    rm -rf gcc/build
    mkdir -p gcc/build
    pushd gcc >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    pushd gcc-*/
      patch -p1 < "$SCRIPT_PATH/cfns-fix-mismatch-in-gnu_inline-attributes.patch"
      patch -p1 < "$SCRIPT_PATH/cpp-musl-support.patch"
    popd

    cd build

    CC_FOR_TARGET="$NEW_GCC" ../gcc-*/configure \
        --enable-languages=c,c++ \
        $GCC_CONFIGURE

    make -j"$JOBS" CC_FOR_TARGET="$NEW_GCC"
    make install

    popd >& /dev/null

fi

popd >& /dev/null
