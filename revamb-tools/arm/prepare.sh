#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_PATH/../init.sh"
cd "$REVAMB_TOOLS"

mkdir -p arm
pushd arm >& /dev/null

if [ ! -e "$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi/bin/ld" ]; then

    echo "Building ARM binutils"

    BINUTILS_ARCHIVE="binutils-2.25.1.tar.bz2"
    [ ! -e "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/binutils/$BINUTILS_ARCHIVE" -O "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"

    mkdir -p binutils/build
    pushd binutils >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$BINUTILS_ARCHIVE"
    cd build/

    ../binutils-*/configure \
        --build=x86_64-pc-linux-gnu \
        --host=x86_64-pc-linux-gnu \
        --target=armv7a-hardfloat-linux-uclibceabi \
        --prefix=$INSTALL_PATH/usr \
        --with-sysroot=$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi \
        --datadir=$INSTALL_PATH/usr/share/binutils-data/armv7a-hardfloat-linux-uclibceabi/2.25.1 \
        --infodir=$INSTALL_PATH/usr/share/binutils-data/armv7a-hardfloat-linux-uclibceabi/2.25.1/info \
        --mandir=$INSTALL_PATH/usr/share/binutils-data/armv7a-hardfloat-linux-uclibceabi/2.25.1/man \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/binutils-bin/2.25.1 \
        --libdir=$INSTALL_PATH/usr/lib64/binutils/armv7a-hardfloat-linux-uclibceabi/2.25.1 \
        --libexecdir=$INSTALL_PATH/usr/lib64/binutils/armv7a-hardfloat-linux-uclibceabi/2.25.1 \
        --includedir=$INSTALL_PATH/usr/lib64/binutils/armv7a-hardfloat-linux-uclibceabi/2.25.1/include \
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

if [ ! -e "$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi/usr/include/stdio.h" ]; then

    echo "Installing ARM uClibc headers"

    UCLIBC_ARCHIVE=uClibc-0.9.33.2.tar.bz2
    [ ! -e "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE" ] && wget "https://uclibc.org/downloads/$UCLIBC_ARCHIVE" -O "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE"

    BUILD_DIR="uclibc/headers"
    mkdir -p "$BUILD_DIR"
    pushd "$BUILD_DIR" >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE"

    cd uClibc-*
    make ARCH=arm defconfig

    cp "$SCRIPT_PATH/uClibc.config" .config
    sed 's|$INSTALL_PATH|'"$INSTALL_PATH"'|g' .config -i
    yes "" | make oldconfig

    make headers
    make DESTDIR="$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi" install_headers

    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi/usr/include/linux/errno.h" ]; then
    LINUX_ARCHIVE=linux-4.5.2.tar.xz
    [ ! -e "$DOWNLOAD_PATH/$LINUX_ARCHIVE" ] && wget "https://cdn.kernel.org/pub/linux/kernel/v4.x/$LINUX_ARCHIVE" -O "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    mkdir -p linux-headers
    pushd linux-headers >& /dev/null
    tar xaf "$DOWNLOAD_PATH/$LINUX_ARCHIVE"

    cd linux-*
    make ARCH=arm INSTALL_HDR_PATH="$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi/usr" headers_install

    popd >& /dev/null
fi

NEW_GCC="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/gcc-bin/4.9.3/armv7a-hardfloat-linux-uclibceabi-gcc"
GCC_CONFIGURE=$(echo --host=x86_64-pc-linux-gnu \
        --build=x86_64-pc-linux-gnu \
        --target=armv7a-hardfloat-linux-uclibceabi \
        --prefix=$INSTALL_PATH/usr \
        --bindir=$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/gcc-bin/4.9.3 \
        --includedir=$INSTALL_PATH/usr/lib/gcc/armv7a-hardfloat-linux-uclibceabi/4.9.3/include \
        --datadir=$INSTALL_PATH/usr/share/gcc-data/armv7a-hardfloat-linux-uclibceabi/4.9.3 \
        --mandir=$INSTALL_PATH/usr/share/gcc-data/armv7a-hardfloat-linux-uclibceabi/4.9.3/man \
        --infodir=$INSTALL_PATH/usr/share/gcc-data/armv7a-hardfloat-linux-uclibceabi/4.9.3/info \
        --with-gxx-include-dir=$INSTALL_PATH/usr/lib/gcc/armv7a-hardfloat-linux-uclibceabi/4.9.3/include/g++-v4 \
        --with-python-dir=/share/gcc-data/armv7a-hardfloat-linux-uclibceabi/4.9.3/python \
        --with-sysroot=$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi \
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
        --enable-__cxa_atexit \
        --enable-tls \
        --enable-clocale=gnu \
        --disable-multilib \
        --disable-altivec \
        --disable-fixed-point \
        --with-float=softfp \
        --with-arch=armv7-a \
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
        --disable-libsanitizer)

if [ ! -e "$NEW_GCC" ]; then

    echo "Building ARM gcc"

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

    make -j"$JOBS"
    make install

    popd >& /dev/null

fi

export PATH="$(dirname $NEW_GCC):$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/binutils-bin/2.25.1/:$PATH"

if [ ! -e "$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi/usr/lib/libc.a" ]; then

    UCLIBC_ARCHIVE=uClibc-0.9.33.2.tar.bz2
    [ ! -e "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE" ] && wget "https://uclibc.org/downloads/$UCLIBC_ARCHIVE" -O "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE"

    for CONFIG in ${CONFIGS[@]}; do
        echo "Building ARM uClibc $CONFIG"

        BUILD_DIR="uclibc/build-$CONFIG"
        FLAGS_NAME="CFLAGS_$CONFIG"
        FLAGS="${!FLAGS_NAME}"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
        pushd "$BUILD_DIR" >& /dev/null
        tar xaf "$DOWNLOAD_PATH/$UCLIBC_ARCHIVE"

        cd uClibc-*
        patch -p1 < "$SCRIPT_PATH/blt-blo.patch"

        make ARCH=arm defconfig
        cp "$SCRIPT_PATH/uClibc.config" .config
        sed 's|$INSTALL_PATH|'"$INSTALL_PATH"'|g' .config -i
        sed 's|$FLAGS|'"$FLAGS"'|g' .config -i
        yes "" | make oldconfig

        sed 's|^typedef __kernel_dev_t\s*__kernel_old_dev_t;$|\0\ntypedef long __kernel_long_t;\ntypedef unsigned long __kernel_ulong_t;|' libc/sysdeps/linux/arm/bits/kernel_types.h -i

        make -j"$JOBS"

        popd >& /dev/null
    done

fi

CHOSEN_CONFIG="${CHOSEN_CONFIG:-default}"
if [ -e "uclibc/build-$CHOSEN_CONFIG" ]; then

    echo "Installing arm uClibc $CHOSEN_CONFIG"
    pushd "uclibc/build-$CHOSEN_CONFIG" >& /dev/null
    cd uClibc-*
    make -j"$JOBS" DESTDIR="$INSTALL_PATH/usr/armv7a-hardfloat-linux-uclibceabi" install
    popd >& /dev/null

fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/gcc-bin/4.9.3/armv7a-hardfloat-linux-uclibceabi-g++" ]; then

    echo "Building ARM g++"

    GCC_ARCHIVE="gcc-4.9.3.tar.gz"
    [ ! -e "$DOWNLOAD_PATH/$GCC_ARCHIVE" ] && wget "https://ftp.gnu.org/gnu/gcc/gcc-4.9.3/$GCC_ARCHIVE" -O "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    rm -rf gcc/build
    mkdir -p gcc/build
    pushd gcc >& /dev/null

    tar xaf "$DOWNLOAD_PATH/$GCC_ARCHIVE"

    pushd gcc-*/
      patch -p1 < "$SCRIPT_PATH/cfns-fix-mismatch-in-gnu_inline-attributes.patch"
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
