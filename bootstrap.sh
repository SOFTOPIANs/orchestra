#!/bin/bash

set -e

# Variables initialization
# ========================

# Default values
# --------------

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$SCRIPT_PATH/root"
BUILD_PATH="$SCRIPT_PATH/build"
JOBS="$(nproc || echo 1)"
BRANCH=develop
CLEAN=0

# Parse parameters
# ----------------

while [[ $# > 0 ]]
do
    key="$1"
    case $key in
        --install-path)
            shift
            INSTALL_PATH="$1"
            shift
            ;;
        --build-path)
            shift
            BUILD_PATH="$1"
            shift
            ;;
        --jobs)
            shift
            JOBS="$1"
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --branch)
            shift
            BRANCH="$1"
            shift
            ;;
        *)
            cat <<EOF
Usage: $0 [--install-path INSTALL_PATH] [--build-path BUILD_PATH] [--jobs JOBS]
          [--branch BRANCH] [--clean]

--install-path where to install all the necessary components. Default: "root/".
--build-path   where to keep all build files. Default: "build/".
--jobs         the number of parallel jobs for the builds. Default: $JOBS.
--branch       the branch to use in all the cloned repositories (if available).
               Default: develop.
--clean        Remove all the build directories after a successful build, except
               for revamb. Default: don't clean.
EOF
            exit 1
            ;;
    esac
done

# Checkout code
# =============

"$SCRIPT_PATH/repo-rehab" clone --branch "$BRANCH"

# Build
# =====

mkdir -p "$INSTALL_PATH"
mkdir -p "$BUILD_PATH"

cd "$BUILD_PATH"

# Build LLVM and clang
# --------------------

if [ -d llvm ]; then
    echo "llvm build directory already exists, skipping"
else

    mkdir llvm
    cd llvm
    cat > ../configure-llvm <<EOF
cmake "$SCRIPT_PATH/llvm" \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
      -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" \
      -DLLVM_EXTERNAL_CLANG_BUILD=N \
      -DBUILD_SHARED_LIBS=ON \
      -Wno-dev
EOF
    bash ../configure-llvm

    make -j"$JOBS"
    make install

    cd ..

fi

# Build compiler-rt
# -----------------

if [ -d compiler-rt ]; then
    echo "compiler-rt build directory already exists, skipping"
else

    mkdir compiler-rt
    cd compiler-rt

    cat > ../configure-compiler-rt <<EOF
cmake "$SCRIPT_PATH/compiler-rt" \
      -DLLVM_CONFIG_PATH="$INSTALL_PATH/bin/llvm-config" \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" \
      -DCMAKE_C_FLAGS="-mlong-double-64" \
      -DCMAKE_CXX_FLAGS="-mlong-double-64" \
      -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=x86_64-gentoo-linux \
      -DCMAKE_BUILD_TYPE=Release \
      -DCAN_TARGET_i386=False \
      -DCAN_TARGET_i686=False
EOF
    bash ../configure-compiler-rt
    make -j"$JOBS"
    make install

    cd ..

fi

# Build QEMU
# ----------

if [ -d qemu ]; then
    echo "qemu build directory already exists, skipping"
else

    mkdir qemu
    cd qemu

    export LLVM_CONFIG="$INSTALL_PATH/bin/llvm-config"
    cat > ../configure-qemu  <<EOF
"$SCRIPT_PATH/qemu/configure" \
    --prefix="$INSTALL_PATH" \
    --target-list="arm-libtinycode x86_64-libtinycode mips-libtinycode arm-linux-user x86_64-linux-user mips-linux-user i386-libtinycode i386-linux-user" \
    --enable-debug \
    --disable-werror \
    --extra-cflags="-ggdb -O0" \
    --enable-llvm-helpers \
    --disable-kvm \
    --without-pixman \
    --disable-tools \
    --disable-system \
    --python=$(which python2)
EOF
    bash ../configure-qemu

    make -j"$JOBS"
    make install

    cd ..

fi

# Build revamb-tools
# ------------------

if [ -d revamb-tools ]; then
    echo "revamb-tools build directory already exists, skipping"
else

    mkdir revamb-tools
    cd revamb-tools

    export INSTALL_PATH
    export REVAMB_TOOLS="$PWD"

    "$SCRIPT_PATH/revamb-tools/x86-64/prepare.sh"
    "$SCRIPT_PATH/revamb-tools/mips/prepare.sh"
    "$SCRIPT_PATH/revamb-tools/arm/prepare.sh"
    "$SCRIPT_PATH/revamb-tools/i386/prepare.sh"
    "$SCRIPT_PATH/revamb-tools/common/prepare.sh"

    cd ..

fi

if [ ! -e "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/lib/libclang_rt.builtins-x86_64.a" ]; then

    # Create a link to libclang_rt.builtins.a in path that is in the default
    # library search path so that -lclang_rt.builtins-x86_64 can be used without
    # specifying the full path
    ln -s "../../../lib/linux/libclang_rt.builtins-x86_64.a" \
       "$INSTALL_PATH/usr/x86_64-gentoo-linux-musl/lib/"

fi

# Build revamb
# ------------

if [ -d revamb ]; then
    echo "revamb build directory already exists, skipping"
else

    mkdir revamb
    cd revamb

    cat > ../configure-revamb <<EOF
cmake "$SCRIPT_PATH/revamb" \
      -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
      -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" \
      -DCMAKE_BUILD_TYPE="Debug" \
      -DQEMU_INSTALL_PATH="$INSTALL_PATH" \
      -DTEST_CFLAGS_x86_64="-msoft-float -mfpmath=387 -mlong-double-64" \
      -DTEST_LINK_LIBRARIES_x86_64="-lc -lclang_rt.builtins-x86_64" \
      -DLLVM_DIR="$INSTALL_PATH/share/llvm/cmake" \
      -DC_COMPILER_x86_64="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/gcc-bin/4.9.3/x86_64-gentoo-linux-musl-gcc" \
      -DC_COMPILER_mips="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/gcc-bin/5.3.0/mips-unknown-linux-musl-gcc" \
      -DC_COMPILER_i386="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/i386-gentoo-linux-musl/gcc-bin/4.9.3/i386-gentoo-linux-musl-gcc" \
      -DC_COMPILER_arm="$INSTALL_PATH/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/gcc-bin/4.9.3/armv7a-hardfloat-linux-uclibceabi-gcc"
EOF
    (
        source "$SCRIPT_PATH/environment"
        bash ../configure-revamb
        make -j"$JOBS"
        make install
        ctest -j"$JOBS"
    )

    cd ..

fi

cd ..

# Cleanup of build directory
# ==========================
if [ "$CLEAN" -eq 1 ]; then
    rm -rf build/
fi
