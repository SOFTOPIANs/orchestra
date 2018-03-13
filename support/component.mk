$(call option,JOBS,$(shell nproc || echo 1),Number of concurrent jobs)
$(call option,SOURCE_PATH,$(PWD),Path for sources)
$(call option,BUILD_PATH,$(PWD)/build,Path for build directories)
$(call option,INSTALL_PATH,$(PWD)/root,Path for installing components)
$(call option,ARCHIVE_PATH,$(PWD)/archives,Path for storing archives)
$(call option,SOURCE_ARCHIVE_PATH,$(PWD)/source-archives,Path for caching source archives)
$(call option,PATCH_PATH,$(PWD)/patches,Path containing patches for components)
$(call option,REMOTES,$(shell ./get-remote),Space-separated list of remotes of the current repository to try, one after the other, while cloning sources)
$(call option,REMOTES_BASE_URL,$(foreach REMOTE,$(REMOTES),$(shell dirname $$(git config --get remote.$(REMOTE).url))),Space-separated list of repository base URLs to try, one after the other, while cloning sources)
$(call option,BRANCHES,develop master,Space-separated list of git refs such as branches to try to checkout after the sources have been cloned)

define target-to-prefix
$(shell echo $(1) | tr a-z- A-Z_)
endef

# $(1): build target name
# $(2): default build target name
define print-component-build
	@echo '  '$($(1)_TARGET_NAME)$(if $($(1)_CONFIGURE_DEPS),' (depends on: '$(subst |,[order only:],$($(1)_CONFIGURE_DEPS))')',)$(if $(filter $(2),$(1)),' [default]',)

endef

define print-component
	@echo 'Component '$($(1)_TARGET_NAME)
	$(eval TMP := $(call target-to-prefix,$($(1)_DEFAULT_BUILD)))
	$(foreach BUILD,$($(1)_BUILDS),$(call print-component-build,$(BUILD),$(TMP)))
	@echo

endef

.PHONY: help-components
help-components:
	$(foreach COMPONENT,$(COMPONENTS),$(call print-component,$(COMPONENT)))

# TODO: add suffix for commit in the file name
# $(1): target to archive
# $(2): archive name
define create-archive
	mv "$(INSTALL_PATH)/" "$(INSTALL_PATH)-tmp/"
	make $(1)
	tar caf $(ARCHIVES_PATH)/$(2) -C "$(INSTALL_PATH)" --owner=0 --group=0 .
	rm -rf "$(INSTALL_PATH)"
	mv "$(INSTALL_PATH)-tmp/" "$(INSTALL_PATH)/"
endef

# $(1): file to touch
define touch
	mkdir -p $(shell dirname $(1))
	touch $(1)
endef

# $(1): build path
# $(2): extra arguments (in particular, build target)
define make
# Make sure we don't pass to submake weird flags
	MAKEFLAGS= make -C "$(1)" -j$(JOBS) $(2)
endef

# TODO: Detect if a clone fails due to a missing repository or connection issues.
#       Looking for the "Connection refused" string in the output seems to be the most reliable approach.
# TODO: Clone and create a remote the same name as the source one.
# $(1): remote-relative path of the repository to clone
# $(2): clone destination path
define clone
	$(foreach REMOTE_BASE_URL,$(REMOTES_BASE_URL),git clone $(REMOTE_BASE_URL)/$(1) $(2) || ) false
	$(foreach BRANCH,$(BRANCHES),git -C $(2) checkout -b $(BRANCH) origin/$(BRANCH) || ) true
endef

# $(1): destination
# $(2): path
# $(3): file name
define download-tar
	mkdir -p $(1)
	mkdir -p $(SOURCE_ARCHIVE_PATH)
	test -e "$(SOURCE_ARCHIVE_PATH)/$(3)" || curl -L "$(2)/$(3)" > "$(SOURCE_ARCHIVE_PATH)/$(3)"
	cd "$(1)" && tar xaf "$(SOURCE_ARCHIVE_PATH)/$(3)" --strip-components=1
endef

# Functions to build components
# =============================

#$(1)-HAS-BEEN-INSTALLED
# $(1): target name
define install-target-file
installed-targets/$(1)
endef

define component-source
$(call component-base,$(1),$(2),$(6))
$(call component-clone,$(1),$(3),$(4),$(5))
endef

# component-clone creates the minimal set of variables and targets required to
# obtain a working component.
define component-base

#
# Rules for $(2) (component-base)
#

$(eval COMPONENTS += $(1))

# Name for targets related to this component
$(eval $(1)_TARGET_NAME := $(2))

$(eval $(1)_INSTALL_TARGET_FILE := $(call install-target-file,$($(1)_TARGET_NAME)))

# Build to install by default
$(call option,$(1)_DEFAULT_BUILD,$(3),Default build to install for $(2))

.PHONY: clean-$($(1)_TARGET_NAME)

$(if $(filter-out $($(1)_TARGET_NAME),$($(1)_DEFAULT_BUILD)),
.PHONY: install-$($(1)_TARGET_NAME)
install-$($(1)_TARGET_NAME): install-$($(1)_DEFAULT_BUILD)
$($(1)_INSTALL_TARGET_FILE): $(call install-target-file,$($(1)_DEFAULT_BUILD))

.PHONY: test-$($(1)_TARGET_NAME)
test-$($(1)_TARGET_NAME): test-$($(1)_DEFAULT_BUILD)

.PHONY: $($(1)_TARGET_NAME)
$($(1)_TARGET_NAME): $($(1)_INSTALL_TARGET_FILE)
,)


endef

# component-clone creates the variables and the targets required to perform a
# clone.
define component-clone

#
# Rules for $(1) (component-clone)
#

# Clone path, relative to the origin
$(eval $(1)_CLONE_PATH := $(2))

# Check out path, relative to $(SOURCE_PATH)
$(eval $(1)_SOURCE_PATH := $(SOURCE_PATH)/$(3))

# File to depend on for check out, relative to $(PREFIX)_SOURCE_PATH
$(eval $(1)_SOURCE_TARGET_FILE := $($(1)_SOURCE_PATH)/$(4))

$($(1)_SOURCE_TARGET_FILE):
$(if $(do-clone-$($(1)_TARGET_NAME)),
$(call do-clone-$($(1)_TARGET_NAME),$($(1)_TARGET_NAME),$($(1)_SOURCE_PATH)),
$(call clone,$($(1)_TARGET_NAME),$($(1)_SOURCE_PATH)))
$(call touch,$($(1)_SOURCE_TARGET_FILE))

.PHONY: clone-$($(1)_TARGET_NAME)
clone-$($(1)_TARGET_NAME): $($(1)_SOURCE_TARGET_FILE)

endef

# 6: target suffix for this build
# 7: suffix for the prefix of this build
define component-build

#
# Rules for $(2) (component-build)
#

$(eval $(7)_BUILDS += $(1))

$(eval $(1)_TARGET_NAME := $(2))

# Build path, relative to $(BUILD_PATH)
$(eval $(1)_BUILD_PATH := $(BUILD_PATH)/$(3))

# File to depend on for configure, relative to $(PREFIX)_BUILD_PATH
$(eval $(1)_CONFIGURE_TARGET_FILE := $($(1)_BUILD_PATH)/$(4))

# File to depend on for configure, relative to $(PREFIX)_BUILD_PATH
$(eval $(1)_INSTALL_TARGET_FILE := $(call install-target-file,$($(1)_TARGET_NAME)))

# List of targets the configure stage should depend on
$(eval $(1)_CONFIGURE_DEPS := $(5))

# Path where the archive should be stored, relative to $(ARCHIVE_PATH)
$(eval $(1)_ARCHIVE_PATH := $(ARCHIVE_PATH)/$(6))

# $(7) is the PREFIX of the corresponding source

# configure- target
.PHONY: configure-$($(1)_TARGET_NAME)
configure-$($(1)_TARGET_NAME) $($(1)_CONFIGURE_TARGET_FILE): $($(7)_SOURCE_TARGET_FILE) $($(1)_CONFIGURE_DEPS)
	mkdir -p $(BUILD_PATH)
$(call do-configure-$($(1)_TARGET_NAME),$($(7)_SOURCE_PATH),$($(1)_BUILD_PATH))
$(call touch,$($(1)_CONFIGURE_TARGET_FILE))

# build- target
.PHONY: build-$($(1)_TARGET_NAME)
build-$($(1)_TARGET_NAME): $($(1)_CONFIGURE_TARGET_FILE)
$(if $(do-build-$($(1)_TARGET_NAME)),
$(call do-build-$($(1)_TARGET_NAME),$($(1)_BUILD_PATH)),
$(call make,$($(1)_BUILD_PATH),))

# test- target
.PHONY: test-$($(1)_TARGET_NAME)
test-$($(1)_TARGET_NAME): build-$($(1)_TARGET_NAME)
$(if $(do-test-$($(1)_TARGET_NAME)),
$(call do-test-$($(1)_TARGET_NAME),$($(1)_BUILD_PATH)),)

# install- target
.PHONY: install-$($(1)_TARGET_NAME)
install-$($(1)_TARGET_NAME) $($(1)_INSTALL_TARGET_FILE): $($(1)_CONFIGURE_TARGET_FILE)
$(if $(do-install-$($(1)_TARGET_NAME)),
$(call do-install-$($(1)_TARGET_NAME),$($(1)_BUILD_PATH)),
$(call make,$($(1)_BUILD_PATH),)
$(call make,$($(1)_BUILD_PATH),install))
$(call touch,$($(7)_INSTALL_TARGET_FILE))
$(call touch,$($(1)_INSTALL_TARGET_FILE))

# clean- target
.PHONY: clean-$($(1)_TARGET_NAME)
clean-$($(1)_TARGET_NAME):
	rm -rf $($(1)_BUILD_PATH)

# Add the clean- target for the current build to the component clean- target
clean-$($(7)_TARGET_NAME): clean-$($(1)_TARGET_NAME)


.PHONY: $($(1)_TARGET_NAME)
$($(1)_TARGET_NAME): $($(1)_INSTALL_TARGET_FILE)

.PHONY: create-archive-$($(1)_TARGET_NAME)
create-archive-$($(1)_TARGET_NAME): $($(1)_ARCHIVE_PATH)
$($(1)_ARCHIVE_PATH):
$(call create-archive,install-$($(1)_TARGET_NAME),$@)

endef

# 1: target name
# 2: File to depend on for check out, relative to $(PREFIX)_SOURCE_PATH
# 3: default variant
define simple-component-source
$(call component-source,$(call target-to-prefix,$(1)),$(1),$(1),$(1),$(2),$(1)$(3))
endef

# CMake-based components
# ----------------------

# 1: source target name
# 2: build name suffix
# 3: File to depend on for configure, relative to $(PREFIX)_BUILD_PATH
# 4: List of targets the configure stage should depend on
define simple-component-build
$(call component-build,$(call target-to-prefix,$(1)$(2)),$(1)$(2),$(1)$(2),$(3),$(4),$(1)$(2).tar.gz,$(call target-to-prefix,$(1)))
endef

# 1: target name
# 2: default build
define cmake-component-source
$(call simple-component-source,$(1),CMakeLists.txt,$(2))
endef

# 1: target name
# 2: build name
# 3: List of targets the configure stage should depend on
define cmake-component-build
$(call simple-component-build,$(1),$(2),CMakeCache.txt,$(3))
endef

# 1: target name
# 2: List of targets the configure stage should depend on
define simple-cmake-component
$(call cmake-component-source,$(1),)
$(call cmake-component-build,$(1),,$(2))
endef

# 1: target name
# 2: List of targets the configure stage should depend on
# 3, 4, 5, 6, 7: name of build targets
define multi-build-cmake-component
$(call cmake-component-source,$(1),-$(3))
$(foreach i,3 4 5 6 7,$(if $($(i)),$(call cmake-component-build,$(1),-$($(i)),$(2))))
endef

# autotools-based components
# --------------------------

# 1: target name
# 2: default build
define autotools-component-source
$(call simple-component-source,$(1),configure,$(2))
endef

# 1: target name
# 2: build name
# 3: List of targets the configure stage should depend on
define autotools-component-build
$(call simple-component-build,$(1),$(2),config.log,$(3))
endef

# 1: target name
# 2: List of targets the configure stage should depend on
define simple-autotools-component
$(call autotools-component-source,$(1),)
$(call autotools-component-build,$(1),,$(2))
endef
