# binutils
# ========

$(eval BINUTILS_ARCHIVE=binutils-$(BINUTILS_VERSION).tar.bz2)
$(eval BINUTILS_PATH := $(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/$(TRIPLE)/binutils-bin/$(BINUTILS_VERSION))
$(eval NEW_GCC_PATH := $(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/$(TRIPLE)/gcc-bin/$(GCC_VERSION)/)
$(eval NEW_GCC := $(NEW_GCC_PATH)/$(TRIPLE)-gcc)
$(eval TOOLCHAIN_TARGET_PREFIX := toolchain/$(TOOLCHAIN)/)
$(eval TOOLCHAIN_VAR_PREFIX := TOOLCHAIN/$(call target-to-prefix,$(TOOLCHAIN))/)
$(eval BIN_PATH += usr/x86_64-pc-linux-gnu/$(TRIPLE)/binutils-bin/$(BINUTILS_VERSION))
$(eval BIN_PATH += usr/x86_64-pc-linux-gnu/$(TRIPLE)/gcc-bin/$(GCC_VERSION))

# Forward declarations for dependencies
$(eval $(TOOLCHAIN_VAR_PREFIX)GCC_STAGE1_INSTALL_TARGET_FILE := $(call install-target-file,$(TOOLCHAIN_TARGET_PREFIX)gcc-stage1))

# TODO: $(1) is unused
# $(1): remote-relative path of the repository to clone
# $(2): clone destination path
define do-clone-$(TOOLCHAIN_TARGET_PREFIX)binutils
$(call download-tar,$(2),https://ftp.gnu.org/gnu/binutils,$(BINUTILS_ARCHIVE))
endef

# $(1): source path
# $(2): build path
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)binutils
	mkdir -p "$(2)"

	cd "$(2)" && "$(1)/configure" \
	    --build=x86_64-pc-linux-gnu \
	    --host=x86_64-pc-linux-gnu \
	    --target=$(TRIPLE) \
	    --with-sysroot=$(INSTALL_PATH)/usr/$(TRIPLE) \
	    --prefix=$(INSTALL_PATH)/usr \
	    --datadir=$(INSTALL_PATH)/usr/share/binutils-data/$(TRIPLE)/$(BINUTILS_VERSION) \
	    --infodir=$(INSTALL_PATH)/usr/share/binutils-data/$(TRIPLE)/$(BINUTILS_VERSION)/info \
	    --mandir=$(INSTALL_PATH)/usr/share/binutils-data/$(TRIPLE)/$(BINUTILS_VERSION)/man \
	    --bindir=$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/$(TRIPLE)/binutils-bin/$(BINUTILS_VERSION) \
	    --libdir=$(INSTALL_PATH)/usr/lib64/binutils/$(TRIPLE)/$(BINUTILS_VERSION) \
	    --libexecdir=$(INSTALL_PATH)/usr/lib64/binutils/$(TRIPLE)/$(BINUTILS_VERSION) \
	    --includedir=$(INSTALL_PATH)/usr/lib64/binutils/$(TRIPLE)/$(BINUTILS_VERSION)/include \
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
endef

$(eval $(call simple-autotools-component,$(TOOLCHAIN_TARGET_PREFIX)binutils,))

ifdef UCLIBC_VERSION

# uClibc
# ======

# headers
# -------

# $(1): source path
# $(2): build path
# $(3): extra flags variable name
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc-common
	mkdir -p "$(2)"

$(call download-tar,$(2),https://uclibc.org/downloads,uClibc-$(UCLIBC_VERSION).tar.bz2)
	cd "$(2)" && \
	  make ARCH=$(UCLIBC_ARCH_NAME) defconfig && \
	  cp "$(PATCH_PATH)/uClibc.config" .config && \
	  sed 's|$$$$INSTALL_PATH|'"$(INSTALL_PATH)"'|g' .config -i && \
	  sed 's|$$$$FLAGS|'"$($(3))"'|g' .config -i && \
	  yes "" | make oldconfig && \
	  patch -p1 < "$(PATCH_PATH)/blt-blo.patch" && \
	  sed 's|^typedef __kernel_dev_t\s*__kernel_old_dev_t;$$$$|\0\ntypedef long __kernel_long_t;\ntypedef unsigned long __kernel_ulong_t;|' libc/sysdeps/linux/arm/bits/kernel_types.h -i
endef

define do-build-$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers
	make -C $(1) headers
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers
	make -C $(1) headers
	make -C $(1) DESTDIR="$$$$DESTDIR$(INSTALL_PATH)/usr/$(TRIPLE)" install_headers
endef

# $(1): source path
# $(2): build path
# $(3): extra flags variable name
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc-common,$(1),$(2),$(3))
endef

$(eval $(call component-base,$(TOOLCHAIN_VAR_PREFIX)UCLIBC_HEADERS,$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers,$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers))
$(eval $(call simple-component-build,$(TOOLCHAIN_TARGET_PREFIX)uclibc-headers,,config.log,))

$(TOOLCHAIN_VAR_PREFIX)LIBC_HEADERS_INSTALL_TARGET_FILE := $($(TOOLCHAIN_VAR_PREFIX)UCLIBC_HEADERS_INSTALL_TARGET_FILE)
$(TOOLCHAIN_TARGET_PREFIX)libc-headers: $(TOOLCHAIN_TARGET_PREFIX)uclibc-headers

# Actual builds
# -------------

# $(1): source path
# $(2): build path
# $(3): extra flags variable name
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc-common,$(1),$(2),$(3))
endef


define do-build-$(TOOLCHAIN_TARGET_PREFIX)uclibc
	PATH="$(NEW_GCC_PATH):$(BINUTILS_PATH):$$$$PATH" make -C $(1)
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)uclibc
	PATH="$(NEW_GCC_PATH):$(BINUTILS_PATH):$$$$PATH" make -C $(1)
	PATH="$(NEW_GCC_PATH):$(BINUTILS_PATH):$$$$PATH" make -C $(1) install DESTDIR="$$$$DESTDIR$(INSTALL_PATH)/usr/$(TRIPLE)"
endef


# $(1): build suffix
# $(2): extra flags variable name
define $(TOOLCHAIN_TARGET_PREFIX)uclibc-template

define do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc$(1)
$$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)uclibc,$$(1),$$(2),$(2))
endef

define do-build-$(TOOLCHAIN_TARGET_PREFIX)uclibc$(1)
$$(call do-build-$(TOOLCHAIN_TARGET_PREFIX)uclibc,$$(1),$$(2),$(2))
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)uclibc$(1)
$$(call do-install-$(TOOLCHAIN_TARGET_PREFIX)uclibc,$$(1),$$(2),$(2))
endef

$$(eval $$(call simple-component-build,$(TOOLCHAIN_TARGET_PREFIX)uclibc,$(1),config.log,$($(TOOLCHAIN_VAR_PREFIX)GCC_STAGE1_INSTALL_TARGET_FILE)))

endef

$(eval $(call component-base,$(TOOLCHAIN_VAR_PREFIX)UCLIBC,$(TOOLCHAIN_TARGET_PREFIX)uclibc,$(TOOLCHAIN_TARGET_PREFIX)uclibc-$(LIBC_DEFAULT_CONFIG)))
$(foreach LIBC_CONFIG,$(LIBC_CONFIGS),$(eval $(call $(TOOLCHAIN_TARGET_PREFIX)uclibc-template,-$(LIBC_CONFIG),LIBC_CONFIG_$(call target-to-prefix,$(LIBC_CONFIG))_FLAGS)))

$(TOOLCHAIN_VAR_PREFIX)LIBC_INSTALL_TARGET_FILE := $($(TOOLCHAIN_VAR_PREFIX)UCLIBC_INSTALL_TARGET_FILE)
$(TOOLCHAIN_TARGET_PREFIX)libc: $(TOOLCHAIN_TARGET_PREFIX)uclibc

endif

ifdef MUSL_VERSION

# musl
# ====

# headers
# -------

# $(1): source path
# $(2): build path
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl-common
	mkdir -p "$(2)"

$(call download-tar,$(2),http://www.musl-libc.org/releases/,musl-$(MUSL_VERSION).tar.gz)

	cd "$(2)" && patch -p1 < "$(PATCH_PATH)/musl-$(MUSL_VERSION)-printf-floating-point-rounding.patch"
	cd "$(2)" && cp arch/{arm,x86_64}/bits/float.h
endef

define do-build-$(TOOLCHAIN_TARGET_PREFIX)musl-headers
	make -C $(1) include/bits/alltypes.h
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)musl-headers
	make -C $(1) include/bits/alltypes.h
	make -C $(1) install-headers
endef

# $(1): source path
# $(2): build path
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl-headers
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl-common,$(1),$(2))
	cd "$(2)" && CC=true "$(2)/configure" \
	        --target=$(TRIPLE) \
	        --prefix="$(INSTALL_PATH)/usr/$(TRIPLE)/usr" \
	        --syslibdir="$(INSTALL_PATH)/usr/$(TRIPLE)/lib" \
	        --disable-gcc-wrapper
endef

$(eval $(call component-base,$(TOOLCHAIN_VAR_PREFIX)MUSL_HEADERS,$(TOOLCHAIN_TARGET_PREFIX)musl-headers,$(TOOLCHAIN_TARGET_PREFIX)musl-headers))
$(eval $(call simple-component-build,$(TOOLCHAIN_TARGET_PREFIX)musl-headers,,config.log,))

# $(1): source path
# $(2): build path
# $(3): extra flags variable name
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl-common,$(1),$(2))
	cd "$(2)" && CC="$(NEW_GCC)" \
	LIBCC="$(MUSL_LIBCC)" \
	CFLAGS="$(MUSL_CFLAGS) $($(3))" \
	"$(2)/configure" \
	        --target=$(TRIPLE) \
	        --prefix="$(INSTALL_PATH)/usr/$(TRIPLE)/usr" \
	        --syslibdir="$(INSTALL_PATH)/usr/$(TRIPLE)/lib" \
	        --disable-gcc-wrapper
endef

# $(1): build suffix
# $(2): extra flags variable name
define $(TOOLCHAIN_TARGET_PREFIX)musl-template

define do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl$(1)
$$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)musl,$$(1),$$(2),$(2))
endef

$$(eval $$(call simple-component-build,$(TOOLCHAIN_TARGET_PREFIX)musl,$(1),config.log,$($(TOOLCHAIN_VAR_PREFIX)GCC_STAGE1_INSTALL_TARGET_FILE)))

endef

$(eval $(call component-base,$(TOOLCHAIN_VAR_PREFIX)MUSL,$(TOOLCHAIN_TARGET_PREFIX)musl,$(TOOLCHAIN_TARGET_PREFIX)musl-$(LIBC_DEFAULT_CONFIG)))
$(foreach LIBC_CONFIG,$(LIBC_CONFIGS),$(eval $(call $(TOOLCHAIN_TARGET_PREFIX)musl-template,-$(LIBC_CONFIG),LIBC_CONFIG_$(call target-to-prefix,$(LIBC_CONFIG))_FLAGS)))

$(TOOLCHAIN_VAR_PREFIX)LIBC_HEADERS_INSTALL_TARGET_FILE := $($(TOOLCHAIN_VAR_PREFIX)MUSL_HEADERS_INSTALL_TARGET_FILE)
$(TOOLCHAIN_VAR_PREFIX)LIBC_INSTALL_TARGET_FILE := $($(TOOLCHAIN_VAR_PREFIX)MUSL_INSTALL_TARGET_FILE)

$(TOOLCHAIN_TARGET_PREFIX)libc-headers: $(TOOLCHAIN_TARGET_PREFIX)musl-headers
$(TOOLCHAIN_TARGET_PREFIX)libc: $(TOOLCHAIN_TARGET_PREFIX)musl

endif

# Linux headers
# =============

define do-build-$(TOOLCHAIN_TARGET_PREFIX)linux-headers
	make -C $(1) ARCH=$(LINUX_ARCH_NAME) INSTALL_HDR_PATH="$$$$DESTDIR$(INSTALL_PATH)/usr/$(TRIPLE)/usr" headers_install
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)linux-headers
	make -C $(1) ARCH=$(LINUX_ARCH_NAME) INSTALL_HDR_PATH="$$$$DESTDIR$(INSTALL_PATH)/usr/$(TRIPLE)/usr" headers_install
endef

# $(1): source path
# $(2): build path
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)linux-headers
	mkdir -p "$(2)"

$(call download-tar,$(2),https://cdn.kernel.org/pub/linux/kernel/v4.x,linux-$(LINUX_VERSION).tar.xz)

endef

$(eval $(call component-base,$(TOOLCHAIN_VAR_PREFIX)LINUX_HEADERS,$(TOOLCHAIN_TARGET_PREFIX)linux-headers,$(TOOLCHAIN_TARGET_PREFIX)linux-headers))
$(eval $(call simple-component-build,$(TOOLCHAIN_TARGET_PREFIX)linux-headers,,Makefile,))

# GCC
# ===

# TODO: $(1) is unused
# $(1): remote-relative path of the repository to clone
# $(2): clone destination path
define do-clone-$(TOOLCHAIN_TARGET_PREFIX)gcc
$(call download-tar,$(2),https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION),gcc-$(GCC_VERSION).tar.gz)
	cd "$(2)" && patch -p1 < "$(PATCH_PATH)/gcc-$(GCC_VERSION)-cfns-fix-mismatch-in-gnu_inline-attributes.patch"
	cd "$(2)" && patch -p1 < "$(PATCH_PATH)/gcc-$(GCC_VERSION)-cpp-musl-support.patch"
endef

# $(1): source path
# $(2): build path
# $(3): extra configure options
define do-configure-$(TOOLCHAIN_TARGET_PREFIX)gcc
	mkdir -p "$(2)"

	cd "$(2)" && "$(1)/configure" \
	        --host=x86_64-pc-linux-gnu \
	        --build=x86_64-pc-linux-gnu \
	        --target=$(TRIPLE) \
	        --prefix=$(INSTALL_PATH)/usr \
	        --bindir=$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/$(TRIPLE)/gcc-bin/$(GCC_VERSION) \
	        --includedir=$(INSTALL_PATH)/usr/lib/gcc/$(TRIPLE)/$(GCC_VERSION)/include \
	        --datadir=$(INSTALL_PATH)/usr/share/gcc-data/$(TRIPLE)/$(GCC_VERSION) \
	        --mandir=$(INSTALL_PATH)/usr/share/gcc-data/$(TRIPLE)/$(GCC_VERSION)/man \
	        --infodir=$(INSTALL_PATH)/usr/share/gcc-data/$(TRIPLE)/$(GCC_VERSION)/info \
	        --with-gxx-include-dir=$(INSTALL_PATH)/usr/lib/gcc/$(TRIPLE)/$(GCC_VERSION)/include/g++-v4 \
	        --with-sysroot=$(INSTALL_PATH)/usr/$(TRIPLE) \
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
	        --disable-libgcj \
	        --disable-libgomp \
	        --disable-libmudflap \
	        --disable-libssp \
	        --disable-libcilkrts \
	        --disable-vtable-verify \
	        --disable-libvtv \
	        --disable-libquadmath \
	        --enable-lto \
	        --disable-libsanitizer \
	        $(EXTRA_GCC_CONFIGURE_OPTIONS) \
	        $(3)
endef

define do-configure-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage1
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)gcc,$(1),$(2),--enable-languages=c)
endef

define do-configure-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage2
$(call do-configure-$(TOOLCHAIN_TARGET_PREFIX)gcc,$(1),$(2),--enable-languages=c,c++)
endef

define do-build-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage1
$(call make,$(1),CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)")
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage1
$(call make,$(1),CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)")
$(call make,$(1),install)
endef

define do-build-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage2
$(call make,$(1),CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)")
endef

define do-install-$(TOOLCHAIN_TARGET_PREFIX)gcc-stage2
$(call make,$(1),CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)")
$(call make,$(1),install)
endef

$(eval $(call autotools-component-source,$(TOOLCHAIN_TARGET_PREFIX)gcc,-stage2))
$(eval $(call autotools-component-build,$(TOOLCHAIN_TARGET_PREFIX)gcc,-stage1,$($(TOOLCHAIN_VAR_PREFIX)LIBC_HEADERS_INSTALL_TARGET_FILE) $($(TOOLCHAIN_VAR_PREFIX)LINUX_HEADERS_INSTALL_TARGET_FILE) $($(TOOLCHAIN_VAR_PREFIX)BINUTILS_INSTALL_TARGET_FILE) $(DEPS)))
$(eval $(call autotools-component-build,$(TOOLCHAIN_TARGET_PREFIX)gcc,-stage2,$($(TOOLCHAIN_VAR_PREFIX)LIBC_INSTALL_TARGET_FILE)))

.PHONY: toolchain-$(TOOLCHAIN)
toolchain-$(TOOLCHAIN): $(TOOLCHAIN_TARGET_PREFIX)gcc-stage2

toolchain: toolchain-$(TOOLCHAIN)

$(eval TOOLCHAIN_INSTALL_TARGET_FILE += $($(TOOLCHAIN_VAR_PREFIX)GCC_STAGE2_INSTALL_TARGET_FILE))
