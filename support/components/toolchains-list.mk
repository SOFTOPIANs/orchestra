# This file stays on its own so that we do not trigger a rebuild of all the
# toolchains in case a new toolchain is appended

include support/components/toolchain/x86_64.mk
include support/components/toolchain/i386.mk
include support/components/toolchain/arm.mk
include support/components/toolchain/aarch64.mk
include support/components/toolchain/s390x.mk
include support/components/toolchain/mips.mk
include support/components/toolchain/mipsel.mk
