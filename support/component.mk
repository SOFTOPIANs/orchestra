define platform-name
$(subst $(SPACE),-,$(subst _,-,$(call lc,$(shell uname -ms))))
endef

# $(1): string
define lc
$(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$(1)))))))))))))))))))))))))))
endef

# $(1): string
define uc
$(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$(1)))))))))))))))))))))))))))
endef

$(call option,JOBS,$(shell nproc || echo 1),Number of concurrent jobs)
$(call option,SOURCE_PATH,$(PWD),Path for sources)
$(call option,BUILD_PATH,$(PWD)/build,Path for build directories)
$(call option,INSTALL_PATH,$(PWD)/root,Path for installing components)
$(call option,PLATFORM_NAME,$(call platform-name),Name of the platform used to archive binaries)
$(call option,BINARY_ARCHIVE_PATH,$(PWD)/binary-archives,Path for storing and fetching binary archives)
$(call option,SOURCE_ARCHIVE_PATH,$(PWD)/source-archives,Path for caching source archives)
$(call option,PATCH_PATH,$(PWD)/patches,Path containing patches for components)
$(call option,TEMP_INSTALL_PATH,$(PWD)/temp-install,Path for installing components before creating a binary archive)
$(call option,INSTALLED_TARGETS_PATH,$(PWD)/installed-targets,Path for the file to indicate that a certain build/component has been installed)
$(call option,REMOTES,$(shell ./get-remote),Space-separated list of remotes of the current repository to try, one after the other, while cloning sources)
$(call option,REMOTES_BASE_URL,$(foreach REMOTE,$(REMOTES),$(dir $(shell git config --get remote.$(REMOTE).url))),Space-separated list of repository base URLs to try, one after the other, while cloning sources)
$(call option,BRANCHES,develop master,Space-separated list of git refs such as branches to try to checkout after the sources have been cloned)
$(call option,CLONE_ATTEMPTS,3,Attempts to clone a remote before giving up)
$(call option,CLONE_ATTEMPTS_PAUSE,10,Seconds to wait before an attempt to clone a remote and the next one)
$(eval CLONE_ATTEMPTS_LOOP := $(shell seq $(CLONE_ATTEMPTS)))

# $(shell echo $(1) | tr a-z- A-Z_)
define target-to-prefix
$(subst -,_,$(call uc,$(1)))
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

# $(1): file to touch
define touch
	mkdir -p $(dir $(1)) && touch $(1)
endef

define string-to-suffix
$(subst /,-,$(1))
endef

# $(1): target name
define binary-archive-directory
$(BINARY_ARCHIVE_PATH)/$(PLATFORM_NAME)/$(1)
endef

# $(1): target name
# $(2): suffix
define binary-archive-name
$(call binary-archive-directory,$(1))/$(2).tar.gz
endef

# $(1): target to archive
# $(2): source path
# $(3): target install file
define create-binary-archive
	rm -rf "$(TEMP_INSTALL_PATH)"
	mkdir -p "$(TEMP_INSTALL_PATH)"
	make $(3)
	make install-$(1) "DESTDIR=$(TEMP_INSTALL_PATH)"
	$(eval TMP_ARCHIVE_DIRECTORY := $(call binary-archive-directory,$(1)))
	mkdir -p "$(TMP_ARCHIVE_DIRECTORY)"
	touch "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse HEAD).tar.gz"
	cd "$(TEMP_INSTALL_PATH)/$(INSTALL_PATH)"; tar caf "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse HEAD).tar.gz" --owner=0 --group=0 .
	rm -rf "$(TEMP_INSTALL_PATH)"
	if test -n "$$$$(git -C '$(2)' rev-parse --abbrev-ref HEAD)"; then \
	  ln -f -s "$$$$(git -C '$(2)' rev-parse HEAD).tar.gz" "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse --abbrev-ref HEAD | tr '/' '-').tar.gz"; \
	fi
endef

# $(1): target to archive
# $(2): source path
define git-add-binary-archive
	$(eval TMP_ARCHIVE_DIRECTORY := $(call binary-archive-directory,$(1)))
	if test -e "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse HEAD).tar.gz"; then \
	  git -C '$(BINARY_ARCHIVE_PATH)' add "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse HEAD).tar.gz"; \
	fi
	if test -n "$$$$(git -C '$(2)' rev-parse --abbrev-ref HEAD)"; then \
	  if test -e "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse --abbrev-ref HEAD | tr '/' '-').tar.gz"; then \
	    git -C '$(BINARY_ARCHIVE_PATH)' add "$(TMP_ARCHIVE_DIRECTORY)/$$$$(git -C '$(2)' rev-parse --abbrev-ref HEAD | tr '/' '-').tar.gz"; \
	  fi \
	fi
endef

# $(1): build path
# $(2): extra arguments (in particular, build target)
# We unset MAKEFLAGS to make sure we don't pass to submake weird flags
define make
	MAKEFLAGS= make -C "$(1)" -j$(JOBS) $(2)
endef

# $(1) attempts before giving up
# $(2) sleep time between attempts
# $(3) command to retry
define retry
$(LPAR)$(foreach I,$(1),$(3)$(RPAR) || $(LPAR)sleep $(2) && ) false $(RPAR)
endef

# TODO: Detect if a clone fails due to a missing repository or connection issues.
#       Looking for the "Connection refused" string in the output seems to be the most reliable approach.
# TODO: Clone and create a remote the same name as the source one.
# $(1): remote-relative path of the repository to clone
# $(2): clone destination path
define clone
	$(foreach REMOTE_BASE_URL,$(REMOTES_BASE_URL),$(call retry,$(CLONE_ATTEMPTS_LOOP),$(CLONE_ATTEMPTS_PAUSE),GIT_LFS_SKIP_SMUDGE=1 git clone $(REMOTE_BASE_URL)$(1) $(2)) || ) false
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

# git -C "$(BINARY_ARCHIVE_PATH)" lfs pull -I "$$(1)";

# $(1): archive path
define fetch-binary-and-extract
	python support/git-lfs "$(BINARY_ARCHIVE_PATH)" --only "`readlink -f $(1)`"; \
	mkdir -p "$(INSTALL_PATH)"; \
	cd "$(INSTALL_PATH)"; \
	tar xaf "$(1)";
endef

# Functions to build components
# =============================

#$(1)-HAS-BEEN-INSTALLED
# $(1): target name
define install-target-file
$(INSTALLED_TARGETS_PATH)/$(1)
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

.PHONY: create-binary-archive-$($(1)_TARGET_NAME)
create-binary-archive-$($(1)_TARGET_NAME): create-binary-archive-$($(1)_DEFAULT_BUILD)

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

define component-build

#
# Rules for $(2) (component-build)
#

# $(6) is the PREFIX of the corresponding source

$(eval $(6)_BUILDS += $(1))

$(eval $(1)_TARGET_NAME := $(2))

# Build path, relative to $(BUILD_PATH)
$(eval $(1)_BUILD_PATH := $(BUILD_PATH)/$(3))

# File to depend on for configure, relative to $(PREFIX)_BUILD_PATH
$(eval $(1)_CONFIGURE_TARGET_FILE := $($(1)_BUILD_PATH)/$(4))

# File to depend on for configure, relative to $(PREFIX)_BUILD_PATH
$(eval $(1)_INSTALL_TARGET_FILE := $(call install-target-file,$($(1)_TARGET_NAME)))

# List of targets the configure stage should depend on
$(eval $(1)_CONFIGURE_DEPS := $(5))

# configure- target
.PHONY: configure-$($(1)_TARGET_NAME)
configure-$($(1)_TARGET_NAME) $($(1)_CONFIGURE_TARGET_FILE): $($(6)_SOURCE_TARGET_FILE) $($(1)_CONFIGURE_DEPS)
	mkdir -p $(BUILD_PATH)
$(call do-configure-$($(1)_TARGET_NAME),$($(6)_SOURCE_PATH),$($(1)_BUILD_PATH))
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

ifeq ($($(6)_TARGET_NAME),$(filter $($(6)_TARGET_NAME),$(BINARY_COMPONENTS)))
install-$($(1)_TARGET_NAME): $($(1)_CONFIGURE_TARGET_FILE)
else
install-$($(1)_TARGET_NAME) $($(1)_INSTALL_TARGET_FILE): $($(1)_CONFIGURE_TARGET_FILE)
endif
	mkdir -p "$$$$DESTDIR$(INSTALL_PATH)/include"
	mkdir -p "$$$$DESTDIR$(INSTALL_PATH)/lib"
	mkdir -p "$$$$DESTDIR$(INSTALL_PATH)/bin"
	mkdir -p "$$$$DESTDIR$(INSTALL_PATH)/libexec"
$(if $(do-install-$($(1)_TARGET_NAME)),
$(call do-install-$($(1)_TARGET_NAME),$($(1)_BUILD_PATH)),
$(call make,$($(1)_BUILD_PATH),)
$(call make,$($(1)_BUILD_PATH),install))
	rm -f $($(6)_INSTALL_TARGET_FILE)*
$(call touch,$($(6)_INSTALL_TARGET_FILE))
$(call touch,$($(1)_INSTALL_TARGET_FILE))

# clean- target
.PHONY: clean-$($(1)_TARGET_NAME)
clean-$($(1)_TARGET_NAME):
	rm -rf $($(1)_BUILD_PATH)

# Add the clean- target for the current build to the component clean- target
clean-$($(6)_TARGET_NAME): clean-$($(1)_TARGET_NAME)


.PHONY: $($(1)_TARGET_NAME)
$($(1)_TARGET_NAME): $($(1)_INSTALL_TARGET_FILE)

.PHONY: create-binary-archive-$($(1)_TARGET_NAME)
create-binary-archive-$($(1)_TARGET_NAME): $(BINARY_ARCHIVE_PATH)/README.md
$(call create-binary-archive,$($(1)_TARGET_NAME),$($(6)_SOURCE_PATH),$($(1)_INSTALL_TARGET_FILE))

.PHONY: git-add-binary-archive-$($(1)_TARGET_NAME)
git-add-binary-archive-$($(1)_TARGET_NAME): $(BINARY_ARCHIVE_PATH)/README.md
$(call git-add-binary-archive,$($(1)_TARGET_NAME),$($(6)_SOURCE_PATH))

# fetch- target
# $(1): target to fetch
# $(2): source path
# 1. Find the branch
# 2. Get the commit
# 3. Check for the commit file
# 4. Check for the branch file
ifeq ($($(6)_TARGET_NAME),$(filter $($(6)_TARGET_NAME),$(BINARY_COMPONENTS)))
fetch-$($(1)_TARGET_NAME) $($(1)_INSTALL_TARGET_FILE): $(BINARY_ARCHIVE_PATH)/README.md
else
fetch-$($(1)_TARGET_NAME): $(BINARY_ARCHIVE_PATH)/README.md
endif
	TEMP=$$$$(tempfile) || exit; \
	for REMOTE in $(REMOTES_BASE_URL); do \
        trap "rm -f -- '$$$$TEMP'" EXIT; \
	    $(call retry,$(CLONE_ATTEMPTS_LOOP),$(CLONE_ATTEMPTS_PAUSE),git ls-remote -h --refs $$$${REMOTE}$($(6)_TARGET_NAME) > "$$$$TEMP") || true; \
	    if test -s "$$$$TEMP"; then \
		    for BRANCH in $(BRANCHES); do \
	            RES=$$$$( (grep 'refs/heads/'"$$$$BRANCH"'$$$$' "$$$$TEMP" || true) | (grep -o '^[a-z0-9]*' || true) ); \
	            if test -n "$$$$RES"; then \
	                rm -f -- "$$$$TEMP"; \
	                trap - EXIT; \
	                HASH_FILE="$(call binary-archive-directory,$($(1)_TARGET_NAME))/$$$$RES.tar.gz"; \
	                BRANCH_FILE="$(call binary-archive-directory,$($(1)_TARGET_NAME))/$$$$BRANCH.tar.gz"; \
	                if test -e "$$$$HASH_FILE"; then \
	                    $(call fetch-binary-and-extract,$$$$HASH_FILE) \
	                elif test -e "$$$$BRANCH_FILE"; then \
	                    $(call fetch-binary-and-extract,$$$$BRANCH_FILE) \
	                else \
	                    echo "Couldn't find the archive for branch $$$$BRANCH"; \
	                    exit 1; \
	                fi; \
                    exit 0; \
$(call touch,$($(6)_INSTALL_TARGET_FILE)) \
$(call touch,$($(1)_INSTALL_TARGET_FILE)) \
	            fi; \
	        done; \
	    fi; \
	done; \
	exit 1;
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
$(call component-build,$(call target-to-prefix,$(1)$(2)),$(1)$(2),$(1)$(2),$(3),$(4),$(call target-to-prefix,$(1)))
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

# Binaries
$(BINARY_ARCHIVE_PATH)/README.md:
	$(call clone,binary-archives,$(BINARY_ARCHIVE_PATH))
