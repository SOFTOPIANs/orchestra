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

include support/seq.mk

# TODO:
#
# * Time, get peak memory consumption and size targets

# Make sure all is the default build target, we will define it at the end
.PHONY: help
help:

# Include infrastructure files
# ============================

include support/option.mk

define strip-call
$(call $(strip $(1)),$(strip $(2)),$(strip $(3)),$(strip $(4)),$(strip $(5)),$(strip $(6)),$(strip $(7)),$(strip $(8)),$(strip $(9)),$(strip $(10)),$(strip $(11)),$(strip $(12)),$(strip $(13)),$(strip $(14)),$(strip $(15)))
endef

$(call strip-call,option, \
  DEFAULT_TOOLCHAINS, \
  all, \
  List of toolchains to build along with revng)

$(call strip-call,option, \
  BINARY_COMPONENTS, \
  boost \
    llvm \
    toolchain/arm/binutils \
    toolchain/arm/linux-headers \
    toolchain/arm/uclibc \
    toolchain/arm/gcc \
    toolchain/mips/binutils \
    toolchain/mips/linux-headers \
    toolchain/mips/musl \
    toolchain/mips/gcc \
    toolchain/mipsel/binutils \
    toolchain/mipsel/linux-headers \
    toolchain/mipsel/musl \
    toolchain/mipsel/gcc \
    toolchain/i386/binutils \
    toolchain/i386/linux-headers \
    toolchain/i386/musl \
    toolchain/i386/gcc \
    toolchain/x86-64/binutils \
    toolchain/x86-64/linux-headers \
    toolchain/x86-64/musl \
    toolchain/x86-64/gcc \
    toolchain/aarch64/binutils \
    toolchain/aarch64/linux-headers \
    toolchain/aarch64/musl \
    toolchain/aarch64/gcc \
    toolchain/s390x/binutils \
    toolchain/s390x/linux-headers \
    toolchain/s390x/musl \
    toolchain/s390x/gcc, \
  List of components for which binary archives should be used)

include support/component.mk

# Global configuration
# ====================

$(eval BIN_PATH := bin)

$(call patch-if-exists,$(PATCH_PATH)/boost-1.63.0-ignore-Wparentheses-warnings.patch,$(2))


# environment
# ===========

define print-prepend-path
	echo 'export PATH="$$INSTALL_PATH/$(1)$${PATH:+:$${PATH}}"' >> environment

endef

environment: Makefile
	echo 'INSTALL_PATH="$(INSTALL_PATH)"' > environment
	echo >> environment
	$(foreach path,$(BIN_PATH),$(call print-prepend-path,$(path)))
	echo >> environment
	echo 'export LD_LIBRARY_PATH="$$INSTALL_PATH/lib$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}"' >> environment
	echo >> environment
	echo 'export PYTHONPATH="$$INSTALL_PATH/lib/python$${PYTHONPATH:+:$${PYTHONPATH}}"' >> environment
	echo >> environment
	echo 'export QML2_IMPORT_PATH="$$INSTALL_PATH/lib/qt5/qml"' >> environment
	echo >> environment
	echo 'unset INSTALL_PATH' >> environment


# Components
# ==========

include support/components/llvm.mk
include support/components/qemu.mk
include support/components/toolchain.mk
include support/components/boost.mk
include support/components/revng.mk
include support/components/llvmcpy.mk
include support/components/revng-c.mk

# Default targets
# ===============

$(call option,ALL,$(TOOLCHAIN_INSTALL_TARGET_FILE) test-revng,Default targets to build)
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
	@echo 'orchestra enables you to clone and download all the repositories necessary for rev.ng (such as our version of QEMU and LLVM, but also the core project itself, revng).'
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
	@echo '    make toolchain/mips revng'
	@echo
	@echo 'To ensure everything is working properly, run:'
	@echo
	@echo '    make test-revng'
	@echo
	@echo 'For further information on the components that can be built and further customization options, run:'
	@echo
	@echo '    make help-variables'
	@echo '    make help-components'
	@echo

$(call strip-call,option, \
  EXCLUDE_CREATE_BINARY_ARCHIVE_COMPONENTS, \
  , \
  Components to exclude in from CREATE_BINARY_ARCHIVE_COMPONENTS)

$(call strip-call,option, \
  CREATE_BINARY_ARCHIVE_COMPONENTS, \
  $(filter-out $(EXCLUDE_CREATE_BINARY_ARCHIVE_COMPONENTS),$(foreach COMPONENT,$(COMPONENTS),$($(COMPONENT)_TARGET_NAME))), \
  Components to include in create-binary-archive)

.PHONY: create-binary-archive
create-binary-archive: $(foreach COMPONENT,$(CREATE_BINARY_ARCHIVE_COMPONENTS),create-binary-archive-$(COMPONENT))

.PHONY: create-binary-archive-all
create-binary-archive-all: $(foreach COMPONENT,$(CREATE_BINARY_ARCHIVE_COMPONENTS),$(foreach BUILD,$($(call target-to-prefix,$(COMPONENT))_BUILDS),create-binary-archive-$($(BUILD)_TARGET_NAME)))

$(call option,PUSH_BINARY_ARCHIVE_NETRC,,Content of the .netrc file for credentials in the follwoing form: machine HOST login USERNAME password PASSWORD. It will not end up in the logs or in command lines but temporarily on disk.)
$(call option,PUSH_BINARY_ARCHIVE_REMOTE,,Git URL to use to push binary archives. It will not end up in the logs but on the git command line.)
$(call option,PUSH_BINARY_ARCHIVE_EMAIL,orchestra@localhost,E-mail to use for commits for binary archives)
$(call option,PUSH_BINARY_ARCHIVE_NAME,Orchestra,Name to use for commits for binary archives)

# Warning: PUSH_BINARY_ARCHIVE_NETRC can contain a password, we have to make
# sure the URL doesn't end up in the log or in any command line. Environment
# variables should be relatively safe since, unlike the command line, they are
# not world readable.

.PHONY: commit-binary-archive
commit-binary-archive: $(foreach COMPONENT,$(CREATE_BINARY_ARCHIVE_COMPONENTS),$(foreach BUILD,$($(call target-to-prefix,$(COMPONENT))_BUILDS),git-add-binary-archive-$($(BUILD)_TARGET_NAME)))
	git lfs >& /dev/null
	cd '$(BINARY_ARCHIVE_PATH)' && $(PWD)/cleanup-binary-archives.sh
	git -C '$(BINARY_ARCHIVE_PATH)' config user.email "$(PUSH_BINARY_ARCHIVE_EMAIL)"
	git -C '$(BINARY_ARCHIVE_PATH)' config user.name "$(PUSH_BINARY_ARCHIVE_NAME)"
	git -C '$(BINARY_ARCHIVE_PATH)' commit -m'Automatic binary archives'

	rm -f -- $(BINARY_ARCHIVE_PATH)/.netrc
	touch $(BINARY_ARCHIVE_PATH)/.netrc
	chmod 600 $(BINARY_ARCHIVE_PATH)/.netrc
	CONTENT="$$PUSH_BINARY_ARCHIVE_NETRC" support/env-to-file.py '$(BINARY_ARCHIVE_PATH)/.netrc'

	export HOME='$(BINARY_ARCHIVE_PATH)'; \
	trap "rm -f -- $(BINARY_ARCHIVE_PATH)/.netrc" EXIT; \
	cd '$(BINARY_ARCHIVE_PATH)'; \
	git lfs push --object-id $$PUSH_BINARY_ARCHIVE_REMOTE $$(git show -- $$(git diff --name-only HEAD^) | grep '^+oid' | sed 's|.*sha256:\(.*\)$$|\1|') && \
	git push --no-verify $$PUSH_BINARY_ARCHIVE_REMOTE $$(git name-rev --name-only HEAD)

	rm -f -- $(BINARY_ARCHIVE_PATH)/.netrc

# make2graph
# ==========

$(call option,CC,cc,Host compiler)

support/make2graph: support/make2graph.c
	$(CC) $^ -o $@
