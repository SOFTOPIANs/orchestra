$(call option,MIPSEL_TRIPLE,mipsel-unknown-linux-musl)
$(call option,MIPSEL_LINUX_ARCH_NAME,mips)
$(call option,MIPSEL_BINUTILS_VERSION,2.25.1)
$(call option,MIPSEL_MUSL_VERSION,1.1.12)
$(call option,MIPSEL_LINUX_VERSION,4.5.2)
$(call option,MIPSEL_GCC_VERSION,5.3.0)
$(call option,MIPSEL_EXTRA_GCC_CONFIGURE_OPTIONS,--with-abi= --without-isl)
$(call option,MIPSEL_DYNAMIC,0)
$(call prepare-for-toolchain,mipsel)
include support/toolchain.mk