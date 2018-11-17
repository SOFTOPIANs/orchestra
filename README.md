This document illustrates how the `orchestra` repository works.

# Overview

`orchestra` is a repository that takes care of collecting all the `rev.ng` dependencies, such as LLVM, QEMU and all the toolchains for the architectures we handle.

It is based on Makefile.

# Requirements

The most up-to-date list of dependencies not included in orchestra is available in the form of an `apt-get` for Ubuntu command in the `.gitlab-ci.yml` file.

# My first run

```
make test-revamb
```

This command will fetch everything necessary, build some components and run the tests. If they pass, you're ready to go.

# Components and builds

orchestra works on *components*, available in multiple "flavors", i.e., *builds*. This sections describes what they are and how to deal with them.

## Components

The primary goal of orchestra is building *components*. A *components* is basically a project, optionally associated with a source directory. The source can either come from a tarball or from a git repository. If it comes from a git repository, it will be cloned from the same remote URL of orchestra, except for the last portion. For instance, if orchestra has been cloned from `git@rev.ng:my-user/orchestra.git`, LLVM will be cloned from `git@rev.ng:my-user/llvm.git`. In this way, we don't need to hardcode any URL. Note that it is entirely possible to add a custom remote to a git repository. This is indeed the typical workflow: clone orchestra and all the repositories from the official source and then add your own remotes for development.

If a component is associated to a source, by default, it will be cloned/extracted in the orchestra root directory.

Example of components are `llvm`, `qemu`, `revamb` and `toolchain/arm/gcc`. For an updated list, run `make help-components`.

## Builds

Each component can have on or more *build*. A *build* represents a way in which a component can be built. Typically a component has a `-debug` and a `-release` build. For instance, the `llvm` component currently features two builds: `llvm-debug` and `llvm-release`.

Only one build can be installed at a time. Installing a different build will overwrite the previous one. The list of installed components/builds is available in the `installed-targets/` directory in the root of orchestra. To force the reinstallation of a component/build remove the corresponding file there.

It is also possible for a component to have a single build, whose name matches the component name. This is the case for `boost`.

Each component has a *default build*.

By default, builds take place in the `build/` directory. For instance, `llvm-debug` build will reside in `build/llvm-debug`.

For a complete list of components, builds and default builds, run `make help-components`.

## Actions

*Components* and *builds* can have actions. An action is a Makefile target.
Each action ensures that all the depending actions have been executed before running. For example, before building revamb, LLVM will be installed.

### Component actions

* `make clone-$COMPONENT`. Clones the repository of the specified component in the `$COMPONENT` directory in the orchestra root.

### Build actions

* `make fetch-$BUILD`. Fetches the binary archive for the chosen build.
* `make configure-$BUILD`. Configures the component for the chosen build. This typically consists in invoking `configure` or `cmake`.
* `make build-$BUILD`. Launches the actual build. Typically, runs `make`.
* `make test-$BUILD`. Launches the test suite of the component. Typically, runs `ctest` or `make check`.
* `make install-$BUILD`. Installs the result of a build into the `root/` directory.
* `make create-binary-archive-$BUILD`. Installs the build into a temporary directory and creates an archive out of it, storing it in `binary-archives/`.
* `make clean-$BUILD`. Completely removes the build directory.

All these actions work also on components, and will assume the default build. For instance, `make install-llvm` is equivalent to `make install-llvm-release` since `llvm-release` is currently the default build for the `llvm` component.

### Default actions

Each build/component has a default action, which matches its name, and basically ensures that a component/build is installed, either from source or from a binary archive.
For instance `make llvm` will install the default LLVM build. This means that, depending on the configuration, `make install-llvm` or `make fetch-llvm` will be run.

## From binary vs from source

orchestra is able to build from source each component or fetch it from a repository containing binary archives. This repository is `binary-archives` and is cloned in the root. It is an LFS repository, which can become **very** large, but orchestra never fetches all the LFS files at once, it fetches them as needed.

By default all the components are fetched from the binary archives, except for the two project we work on directly the most: QEMU and revamb. Binary archives can save a large amount of space and time.

If you want to build everything from source, simply set the `BINARY_COMPONENTS` to an empty string:

```
make revamb BINARY_COMPONENTS=""
```

# Recap: directories overview

```
orchestra                      orchestra's root directory.
│
├── Makefile                   The main Makefile.
│
├── root                       Install directory for all the components.
├── installed-targets          Directory containing one file per each component/build installed in root/.
│
├── qemu                       The QEMU component source directory (git repository).
├── llvm                       The LLVM component source directory (git repository).
├── revamb                     The revamb component source directory (git repository).
├── ...                        Other component source directories.
│
├── source-archives            Directory containing the source tarballs for projects not built from a git repository.
│   ├── gcc-4.9.3.tar.gz
│   └── ...
├── patches                    Directory containing patches for components built from a tarball (instead than from a git repository).
│
├── boost                      The Boost component source directory (extracted from a tarball).
├── toolchain
│    ├── arm
│    │   ├── binutils          The binutils component source directory (extracted from a tarball).
│    │   ├── gcc               The GCC component source directory (extracted from a tarball).
│    ├── x86-64
│    └── ...
│
├── build                      The directory where all the builds are collected.
│   ├── qemu-debug             Build directory for the qemu-debug build.
│   ├── qemu-release           Build directory for the qemu-release build.
│   ├── toolchain
│   │   ├── arm
│   │   │   ├── binutils       Build directory for binutils for ARM.
│   │   │   ├── gcc-stage1     Build directory for the stage1 GCC for ARM.
│   │   │   ├── gcc-stage2     Build directory for the stage2 GCC for ARM.
│   │   │   ├── linux-headers  Build directory for the Linux headers for ARM.
│   │   │   ├── musl-default   Build directory for the default musl build for ARM.
│   │   │   └── musl-headers   Build directory for musl headers for ARM.
│   │   ├── x86-64
│   │   └── ...
│   └── ...                    Other build directories.
│
├── temp-install               Temporary directory for installing builds and creating binary archives.
├── binary-archives            The "binary-archives" repository. git-lfs repository containing the binary archives of various build.
│
└── support                    Directory containing orchestra support files and scripts.
```

# Variables

orchestra has a large set of options that can be configured through environment variables (e.g., `BINARY_COMPONENTS`). The full list of variables, along with a brief description, is available through `make help-variables`.

# Building bypassing orchestra

Launching build commands bypassing orchestra is fully supported. Just make sure to load the `environment` script in the orchestra's root directory before doing things manually.

```
make configure-revamb
. ./environment
cd build/revamb/
make
```
