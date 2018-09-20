$(call option,ARM_TRIPLE,armv7a-hardfloat-linux-uclibceabi)
$(call option,ARM_LINUX_ARCH_NAME,arm)
$(call option,ARM_UCLIBC_ARCH_NAME,arm)
$(call option,ARM_BINUTILS_VERSION,2.25.1)
$(call option,ARM_UCLIBC_VERSION,0.9.33.2)
$(call option,ARM_LINUX_VERSION,4.5.2)
$(call option,ARM_GCC_VERSION,4.9.3)
$(call option,ARM_EXTRA_GCC_CONFIGURE_OPTIONS,--enable-__cxa_atexit --enable-tls --enable-clocale=gnu --with-float=softfp --with-arch=armv7-a --without-cloog)
$(call option,ARM_DYNAMIC,0)
$(call prepare-for-toolchain,arm)
include support/toolchain.mk
