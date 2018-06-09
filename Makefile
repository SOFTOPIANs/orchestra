# Is this a blatant abuse of Makefiles?
# Only time will say.

.SUFFIXES:
MAKEFLAGS += -r
COMMA := ,
SPACE :=
SPACE +=
LPAR := (
RPAR := )
SHELL := /bin/bash -e

# TODO:
#
# * Binary toolchains
# * CI

# Make sure all is the default build target, we will define it at the end
.PHONY: help
help:

# Include infrastructure files
# ============================

include support/option.mk
include support/component.mk

# Global configuration
# ====================

$(eval BIN_PATH := bin)


# LLVM
# ====

# $(1): source path
# $(2): build path
# $(3): CMAKE_BUILD_TYPE
define do-configure-llvm
	mkdir -p "$(2)"

	cd "$(2)"; \
	cmake "$(1)" \
	      -DCMAKE_BUILD_TYPE=$(3) \
	      -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
	      -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
	      -DLLVM_TARGETS_TO_BUILD="X86" \
	      -DCMAKE_INSTALL_PREFIX="$(INSTALL_PATH)" \
	      -DBUILD_SHARED_LIBS=ON \
	      -Wno-dev
endef

define do-configure-llvm-debug
$(call do-configure-llvm,$(1),$(2),Debug)
endef

define do-configure-llvm-release
$(call do-configure-llvm,$(1),$(2),RelWithDebInfo)
endef

CLANG_SOURCE_PATH := $(SOURCE_PATH)/llvm/tools/clang
CLANG_SOURCE_TARGET_FILE := $(CLANG_SOURCE_PATH)/CMakeLists.txt
.PHONE: clone-clang
clone-clang: $(CLANG_SOURCE_TARGET_FILE)
$(CLANG_SOURCE_TARGET_FILE):
	$(call clone,clang,$(CLANG_SOURCE_PATH))
	$(call touch,$(CLANG_SOURCE_TARGET_FILE))

$(eval $(call multi-build-cmake-component,llvm,$(CLANG_SOURCE_TARGET_FILE),release,debug))

# QEMU
# ====

# $(1): source path
# $(2): build path
define do-configure-qemu
	mkdir -p "$(2)"
	cd "$(2)"; \
    export LLVM_CONFIG="$(INSTALL_PATH)/bin/llvm-config"; \
	"$(1)/configure" \
	    --prefix="$(INSTALL_PATH)" \
	    --target-list="arm-libtinycode x86_64-libtinycode mips-libtinycode arm-linux-user x86_64-linux-user mips-linux-user i386-libtinycode i386-linux-user" \
	    --enable-debug \
	    --disable-werror \
	    --extra-cflags="-ggdb -O0" \
	    --enable-llvm-helpers \
	    --disable-kvm \
	    --without-pixman \
	    --disable-tools \
	    --disable-system \
	    --python=$(shell which python2)
endef

$(eval $(call simple-autotools-component,qemu,$(LLVM_INSTALL_TARGET_FILE)))

# Toolchains
# ==========

$(call option,COREUTILS_VERSION,8.29,Version of coreutils to build)

$(call option,LIBC_CONFIGS,default gc-o0 gc-o1 gc-o2 gc-o3,Name of the configurations of the libc to compile)
$(call option,LIBC_DEFAULT_CONFIG,default,Name of the default configuration to use for the libc)
$(eval LIBC_CONFIG_DEFAULT_FLAGS ?= -ggdb3)
$(eval LIBC_CONFIG_GC_O0_FLAGS ?= -ggdb3 -Wl$$(COMMA)--gc-sections -ffunction-sections -O0)
$(eval LIBC_CONFIG_GC_O1_FLAGS ?= -ggdb3 -Wl$$(COMMA)--gc-sections -ffunction-sections -O1)
$(eval LIBC_CONFIG_GC_O2_FLAGS ?= -ggdb3 -Wl$$(COMMA)--gc-sections -ffunction-sections -O2)
$(eval LIBC_CONFIG_GC_O3_FLAGS ?= -ggdb3 -Wl$$(COMMA)--gc-sections -ffunction-sections -O3)
$(foreach LIBC_CONFIG,$(LIBC_CONFIGS),$(call option,LIBC_CONFIG_$(call target-to-prefix,$(LIBC_CONFIG))_FLAGS,$(LIBC_CONFIG_$(call target-to-prefix,$(LIBC_CONFIG))_FLAGS),Compile flags for $(LIBC_CONFIG)))

# $(1): target prefix for toolchain
define prepare-for-toolchain
$(strip
$(eval TOOLCHAIN := $(1))
$(eval TMP := $(call target-to-prefix,$(1)))
$(eval TRIPLE := $($(TMP)_TRIPLE))
$(eval LINUX_ARCH_NAME := $($(TMP)_LINUX_ARCH_NAME))
$(eval UCLIBC_ARCH_NAME := $($(TMP)_UCLIBC_ARCH_NAME))
$(eval BINUTILS_VERSION := $($(TMP)_BINUTILS_VERSION))
$(eval MUSL_VERSION := $($(TMP)_MUSL_VERSION))
$(eval UCLIBC_VERSION := $($(TMP)_UCLIBC_VERSION))
$(eval LINUX_VERSION := $($(TMP)_LINUX_VERSION))
$(eval GCC_VERSION := $($(TMP)_GCC_VERSION))
$(eval EXTRA_GCC_CONFIGURE_OPTIONS := $($(TMP)_EXTRA_GCC_CONFIGURE_OPTIONS))
$(eval MUSL_CFLAGS := $($(TMP)_MUSL_CFLAGS))
$(eval MUSL_LIBCC := $($(TMP)_MUSL_LIBCC))
$(eval DEPS := $($(TMP)_DEPS))
$(eval DYNAMIC := $($(TMP)_DYNAMIC))
)
endef

$(call option,X86_64_TRIPLE,x86_64-gentoo-linux-musl)
$(call option,X86_64_LINUX_ARCH_NAME,x86_64)
$(call option,X86_64_BINUTILS_VERSION,2.25)
$(call option,X86_64_MUSL_VERSION,1.1.12)
$(call option,X86_64_LINUX_VERSION,4.5.2)
$(call option,X86_64_GCC_VERSION,4.9.3)
$(call option,X86_64_EXTRA_GCC_CONFIGURE_OPTIONS,--without-cloog --enable-targets=all --with-multilib-list=m64 --without-isl)
$(call option,X86_64_DEPS,$(COMPILER_RT_INSTALL_TARGET_FILE))
$(call option,X86_64_DYNAMIC,0)
$(call prepare-for-toolchain,x86-64)
include support/toolchain.mk

$(call option,I386_TRIPLE,i386-gentoo-linux-musl)
$(call option,I386_LINUX_ARCH_NAME,i386)
$(call option,I386_BINUTILS_VERSION,2.25)
$(call option,I386_MUSL_VERSION,1.1.12)
$(call option,I386_LINUX_VERSION,4.5.2)
$(call option,I386_GCC_VERSION,4.9.3)
$(call option,I386_EXTRA_GCC_CONFIGURE_OPTIONS,--without-cloog --enable-targets=all --without-isl)
$(call option,I386_DYNAMIC,0)
$(call prepare-for-toolchain,i386)
include support/toolchain.mk

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

$(call option,MIPS_TRIPLE,mips-unknown-linux-musl)
$(call option,MIPS_LINUX_ARCH_NAME,mips)
$(call option,MIPS_BINUTILS_VERSION,2.25.1)
$(call option,MIPS_MUSL_VERSION,1.1.12)
$(call option,MIPS_LINUX_VERSION,4.5.2)
$(call option,MIPS_GCC_VERSION,5.3.0)
$(call option,MIPS_EXTRA_GCC_CONFIGURE_OPTIONS,--with-abi= --without-isl)
$(call option,MIPS_DYNAMIC,0)
$(call prepare-for-toolchain,mips)
include support/toolchain.mk

# Boost
# =====

define do-build-boost
	cd $(1) && ./b2 --ignore-site-config
endef

define do-install-boost
	cd $(1) && ./b2 --prefix="$$$$DESTDIR$(INSTALL_PATH)" --ignore-site-config install
endef

# $(1): source path
# $(2): build path
define do-configure-boost
	mkdir -p "$(2)"

$(call download-tar,$(2),https://sourceforge.net/projects/boost/files/boost/1.63.0,boost_1_63_0.tar.bz2)

	cd $(2) && ./bootstrap.sh --prefix="$(INSTALL_PATH)" --with-libraries=test
endef

$(eval $(call component-base,BOOST,boost,boost))
$(eval $(call simple-component-build,boost,,,))

# environment
# ===========

define print-prepend-path
	echo 'prepend_path PATH "$$INSTALL_PATH/$(1)"' >> environment

endef

.PHONY: environment
environment:
	cat support/environment-header > environment
	echo >> environment
	echo 'INSTALL_PATH="$(INSTALL_PATH)"' >> environment
	echo >> environment
	$(foreach path,$(BIN_PATH),$(call print-prepend-path,$(path)))
	echo >> environment
	echo 'prepend_path LD_LIBRARY_PATH "$$INSTALL_PATH/lib"' >> environment
	echo >> environment
	cat support/environment-footer >> environment

# revamb
# ======

# $(1): source path
# $(2): build path
define do-configure-revamb
	mkdir -p "$(2)"
	source $(PWD)/environment; \
	cd "$(2)"; \
	cmake "$(1)" \
	      -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
	      -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
	      -DCMAKE_INSTALL_PREFIX="$(INSTALL_PATH)" \
	      -DCMAKE_BUILD_TYPE="Debug" \
	      -DQEMU_INSTALL_PATH="$(INSTALL_PATH)" \
	      -DLLVM_DIR="$(INSTALL_PATH)/share/llvm/cmake" \
	      -DC_COMPILER_x86_64="$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/x86_64-gentoo-linux-musl/gcc-bin/4.9.3/x86_64-gentoo-linux-musl-gcc" \
	      -DC_COMPILER_mips="$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/mips-unknown-linux-musl/gcc-bin/5.3.0/mips-unknown-linux-musl-gcc" \
	      -DC_COMPILER_i386="$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/i386-gentoo-linux-musl/gcc-bin/4.9.3/i386-gentoo-linux-musl-gcc" \
	      -DC_COMPILER_arm="$(INSTALL_PATH)/usr/x86_64-pc-linux-gnu/armv7a-hardfloat-linux-uclibceabi/gcc-bin/4.9.3/armv7a-hardfloat-linux-uclibceabi-gcc" \
	      -DBOOST_ROOT="$(INSTALL_PATH)" \
	      -DBoost_NO_SYSTEM_PATHS=On
endef

# $(1): source path
define do-test-revamb
	source $(PWD)/environment; \
	cd "$(1)"; \
	ctest -j$(JOBS)
endef

$(eval $(call simple-cmake-component,revamb,$(LLVM_INSTALL_TARGET_FILE) $(QEMU_INSTALL_TARGET_FILE) $(BOOST_INSTALL_TARGET_FILE) environment | $(TOOLCHAIN_INSTALL_TARGET_FILE)))

# Binaries
binary-archives:
	$(call clone,binary-archives,$(BINARY_ARCHIVE_PATH))

# Default targets
# ===============

$(call option,ALL,$(TOOLCHAIN_INSTALL_TARGET_FILE) test-revamb,Default targets to build)
all: $(ALL)

.PHONY: clean
clean:
	rm -rf $(BUILD_PATH)/
	rm -rf $(INSTALL_PATH)/
	rm -rf $(SOURCE_ARCHIVE_PATH)/
	rm -rf $(INSTALLED_TARGETS_PATH)/

.PHONY: help
help:
	@echo 'Welcome to the orchestra build system.'
	@echo
	@echo 'orchestra enables you to clone and download all the repositories necessary for rev.ng (such as our version of QEMU and LLVM, but also the core project itself, revamb).'
	@echo 'Moreover, orchestra will also configure, build and install them for you.'
	@echo 'By default, the build will take place in the `build/` directory and the files will be installed in the `root/` directory, so no root permissions are required.'
	@echo
	@echo 'The repositories, by default, will be cloned from the same git namespace as the current one (but you can change this, run `make help-variables` and check out the `REMOTES` and `REMOTES_BASE_URL` options).'
	@echo
	@echo 'By default orchestra will build all the available toolchains and all the other components required by rev.ng. To do this, run:'
	@echo
	@echo '    make all'
	@echo
	@echo 'If you are interested only in working (and running tests) exclusively for a single architecture (e.g., MIPS), instead of running `make all`, run:'
	@echo
	@echo '    make toolchain/mips revamb'
	@echo
	@echo 'To ensure everything is working properly, run:'
	@echo
	@echo '    make test-revamb'
	@echo
	@echo 'For further information on the components that can be built and further customization options, run:'
	@echo
	@echo '    make help-variables'
	@echo '    make help-components'
	@echo

.PHONY: create-binary-archive
create-binary-archive: $(foreach COMPONENT,$(COMPONENTS),create-binary-archive-$($(COMPONENT)_TARGET_NAME))

.PHONY: create-binary-archive-all
create-binary-archive-all: $(foreach COMPONENT,$(COMPONENTS),$(foreach BUILD,$($(COMPONENT)_BUILDS),create-binary-archive-$($(BUILD)_TARGET_NAME)))
