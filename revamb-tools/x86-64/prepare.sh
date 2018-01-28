#!/bin/bash

set -xe

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_PATH/../init.sh"
cd "$REVAMB_TOOLS"

mkdir -p x86-64
pushd x86-64 >& /dev/null

if [ ! -e "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/bin/ld" ]; then

    echo "Building x86-64 binutils"

    BINUTILS_ARCHIVE="binutils-2.25.tar.bz2"
    [ ! -e "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/binutils/$BINUTILS_ARCHIVE" -O "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"

    mkdir -p binutils/build
    pushd binutils/ >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"
    cd build/

    ../binutils-*/configure \
        --build=x86_64-pc-linux-gnu \
        --host=x86_64-pc-linux-gnu \
        --target=x86_64-gentoo-linux-musl \
        --with-sysroot=$INSTALL_PATH/usr/x86_64-gentoo-linux-musl \
        --prefix=$INSTALL_PATH/usr \
        --datadir=$INSTALL_PATH/usr/share/binutils-data/x86_64-gentoo-linux-musl/2.25 \
        --infodir=$INSTALL_PATH/usr/share/binutils-data/x86_64-gentoo-linux-musl/2.25/info \
        --mandir=$INSTALL_PATH/usr/share/binutils-data/x86_64-gentoo-linux-musl/2.25/man \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/binutils-bin/2.25 \
        --libdir=$INSTALL_PATH/usr/lib64/binutils/x86_64-gentoo-linux-musl/2.25 \
        --libexecdir=$INSTALL_PATH/usr/lib64/binutils/x86_64-gentoo-linux-musl/2.25 \
        --includedir=$INSTALL_PATH/usr/lib64/binutils/x86_64-gentoo-linux-musl/2.25/include \
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

if [ ! -e "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr/include/stdio.h" ]; then

    echo "Installing x86-64 musl headers"

    MUSL_ARCHIVE=musl-1.1.12.tar.gz
    [ ! -e "$DOWNLOAD_PATH/$MUSL_ARCHIVE" ] && wget "http://www.musl-libc.org/releases/$MUSL_ARCHIVE" -O "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    mkdir -p musl/build-headers
    pushd musl/build-headers >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    cd musl-*/
    CC=true ../musl-*/configure \
        --target=x86_64-gentoo-linux-musl \
        --prefix="$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr" \
        --syslibdir="$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/lib" \
        --disable-gcc-wrapper

    make include/bits/alltypes.h
    make install-headers

    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr/include/asm/unistd.h" ]; then
    LINUX_ARCHIVE=linux-4.5.2.tar.xz
    [ ! -e "$DOWNLOAD_PATH/$LINUX_ARCHIVE" ] && wget "https://cdn.kernel.org/pub/linux/kernel/v4.x/$LINUX_ARCHIVE" -O "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    mkdir -p linux-headers
    pushd linux-headers >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    cd linux-*
    make ARCH=x86_64 INSTALL_HDR_PATH="$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr" headers_install

    popd >& /dev/null
fi

NEW_GCC="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/gcc-bin/4.9.3/x86_64-gentoo-linux-musl-gcc"
GCC_CONFIGURE=$(echo --host=x86_64-pc-linux-gnu \
        --build=x86_64-pc-linux-gnu \
        --target=x86_64-gentoo-linux-musl \
        --prefix=$INSTALL_PATH/usr \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/gcc-bin/4.9.3 \
        --includedir=$INSTALL_PATH/usr/lib/gcc/x86_64-gentoo-linux-musl/4.9.3/include \
        --datadir=$INSTALL_PATH/usr/share/gcc-data/x86_64-gentoo-linux-musl/4.9.3 \
        --mandir=$INSTALL_PATH/usr/share/gcc-data/x86_64-gentoo-linux-musl/4.9.3/man \
        --infodir=$INSTALL_PATH/usr/share/gcc-data/x86_64-gentoo-linux-musl/4.9.3/info \
        --with-gxx-include-dir=$INSTALL_PATH/usr/lib/gcc/x86_64-gentoo-linux-musl/4.9.3/include/g++-v4 \
        --with-sysroot=$INSTALL_PATH/usr/x86_64-gentoo-linux-musl \
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
        --with-multilib-list=m64 \
        --disable-altivec \
        --disable-fixed-point \
        --enable-targets=all \
        --disable-libgcj \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libssp \
        --disable-libcilkrts \
        --disable-vtable-verify \
        --disable-libvtv \
        --disable-libquadmath \
        --enable-lto \
        --without-cloog \
        --without-isl \
        --disable-libsanitizer)

if [ ! -e "$NEW_GCC" ]; then

    echo "Building x84-64 gcc"

    GCC_ARCHIVE="gcc-4.9.3.tar.gz"
    [ ! -e "$DOWNLOAD_PATH/$GCC_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/gcc/gcc-4.9.3/$GCC_ARCHIVE" -O "$DOWNLOAD_PATH/$GCC_ARCHIVE"

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

    make -j"$JOBS" CFLAGS_FOR_TARGET="-mlong-double-64 -O2 -g"
    make install

    popd >& /dev/null

fi

COMPILER_RT_BUILTINS="$INSTALL_PATH/lib/linux/libclang_rt.builtins-x86_64.a"
if [ ! -e "$COMPILER_RT_BUILTINS" ]; then
    echo "Couldn't find libclang_rt.builtins-x86_64.a"
    false
fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr/lib/libc.a" ]; then

    MUSL_ARCHIVE=musl-1.1.12.tar.gz
    [ ! -e "$DOWNLOAD_PATH/$MUSL_ARCHIVE" ] && wget "http://www.musl-libc.org/releases/$MUSL_ARCHIVE" -O "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

    for CONFIG in ${CONFIGS[@]}; do

        FLAGS_NAME="CFLAGS_$CONFIG"
        FLAGS="${!FLAGS_NAME}"
        echo "Building x86-64 musl $CONFIG"

        BUILD_DIR="musl/build-$CONFIG"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
        pushd "$BUILD_DIR" >& /dev/null
        tar xaf "$DOWNLOAD_PATH/$MUSL_ARCHIVE"

        cd musl-*
        patch -p1 < "$SCRIPT_PATH/musl-printf-floating-point-rounding.patch"
        cp arch/{arm,x86_64}/bits/float.h

        CC="$NEW_GCC" \
          LIBCC="$COMPILER_RT_BUILTINS" \
          CFLAGS="-msoft-float -mfpmath=387 -mlong-double-64 $FLAGS" \
          ../musl-*/configure \
          --target=x86_64-gentoo-linux-musl \
          --prefix="$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/usr" \
          --syslibdir="$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/lib" \
          --disable-gcc-wrapper

        make -j"$JOBS"

        popd >& /dev/null

    done

fi

CHOSEN_CONFIG="${CHOSEN_CONFIG:-default}"
if [ -e "musl/build-$CHOSEN_CONFIG" ]; then

    echo "Installing x86-64 musl $CHOSEN_CONFIG"
    pushd "musl/build-$CHOSEN_CONFIG" >& /dev/null
    cd musl-*
    make install
    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/gcc-bin/4.9.3/x86_64-gentoo-linux-musl-g++" ]; then

    echo "Building x84-64 g++"

    GCC_ARCHIVE="gcc-4.9.3.tar.gz"
    [ ! -e "$DOWNLOAD_PATH/$GCC_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/gcc/gcc-4.9.3/$GCC_ARCHIVE" -O "$DOWNLOAD_PATH/$GCC_ARCHIVE"

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

    make -j"$JOBS" CFLAGS_FOR_TARGET="-mlong-double-64 -O2 -g" CC_FOR_TARGET="$NEW_GCC"
    make install

    popd >& /dev/null

fi

popd >& /dev/null
