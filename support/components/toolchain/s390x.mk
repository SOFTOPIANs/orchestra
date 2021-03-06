$(call option,S390X_TRIPLE,s390x-ibm-linux-musl)
$(call option,S390X_LINUX_ARCH_NAME,s390)
$(call option,S390X_BINUTILS_VERSION,2.29.1)
$(call option,S390X_MUSL_VERSION,1.1.19)
$(call option,S390X_LINUX_VERSION,4.14.18)
$(call option,S390X_GCC_VERSION,7.3.0)
$(call option,S390X_EXTRA_GCC_CONFIGURE_OPTIONS,--without-cloog --without-isl --with-long-double-128)
$(call option,S390X_DYNAMIC,0)
$(call prepare-for-toolchain,s390x)
include support/toolchain.mk
