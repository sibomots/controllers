#!/usr/bin/env bash
#  ============================================================================
#  This file is part of Bifrost
#
#  Copyright (c) 2025 Jeff Wandling
#  All Rights Reserved.
#
#  Licensed under BSD 3-Clause
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted under the terms of the BSD 3-Clause license.
#  See the LICENSE file for the full text.
#  ============================================================================

printHelp() {
   cat <<EOM
BUILDW                    M7 (SAMV71) Build Script (Windows / git-sdk-64)

NAME
    buildw.sh

SYNOPSIS

    buildw.sh [ --help ]
    buildw.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    This shell script configures (via CMake) and builds the m7
    (SAMV71) controller firmware, cross-compiling via the
    arm-none-eabi-gcc toolchain -- the same toolchain c/bifrost and
    c/samv71-squeaky use, nothing new to install.

    This replaces the project's former recursive-Makefile build
    (defs.mk/component.mk + a Makefile per component directory).
    Those are no longer used by this script; CMakeLists.txt now wires
    every component (previously -- and still, Phase A is a faithful
    conversion, not a rewrite -- hal/, hpl/, hri/ included).

    One behavior difference from the old build: the old TOOLPATH
    environment variable is no longer used. Toolchain discovery now
    matches the rest of this repo -- arm-none-eabi-gcc found on PATH.

    This is the Windows flavor, and it REQUIRES the git-sdk-64 build of
    Git-for-Windows bash (https://github.com/git-for-windows/build-extra/releases).

    Plain Git-for-Windows bash (the common one, installed via the usual
    Git for Windows installer) is NOT supported: it ships a minimal
    MSYS2 runtime with no /usr/bin/cmake or /usr/bin/make, and its
    bundled pacman (if present at all) is restricted to Git's own
    self-update and is not a general package manager. git-sdk-64 is a
    full MSYS2 installation and provides both tools via pacman.

    For native Linux, use build.sh instead.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (make VERBOSE=1)

    -c | --clean-only    Remove the build directory and exit; do not
                         reconfigure or rebuild.

DEPENDENCIES

      REQUIRED:

         git-sdk-64 (NOT plain Git-for-Windows bash)
         /usr/bin/cmake    (via: pacman -S mingw-w64-x86_64-cmake)
         /usr/bin/make     (via: pacman -S mingw-w64-x86_64-make)
         arm-none-eabi-gcc on PATH

BUILDW                    M7 (SAMV71) Build Script (Windows / git-sdk-64)
EOM
}

USE_VERBOSE=""
CleanOnly="no"

while [ $# -gt 0 ]
do
   key="$1"
   case $key in
       -v|--verbose)
       USE_VERBOSE="VERBOSE=1"
       shift
       ;;
       -c|--clean-only)
       CleanOnly="yes"
       shift
       ;;
       -h|--help)
       printHelp
       exit 0
       ;;
       *)
       echo "Unknown option: $key"
       printHelp
       exit 1
       ;;
   esac
done

## Sanity: are we even in some flavor of git-bash at all? If this is
## native Linux (or WSL), point at the right script.
case "$(uname -s)" in
    MINGW*|MSYS*)
        : # good, this is some flavor of Windows git-bash -- keep going
        ;;
    *)
        echo "This does not look like a Windows git-bash shell (uname: $(uname -s))."
        echo "Use build.sh instead -- it is the native-Linux flavor of this script."
        exit 1
        ;;
esac

set -e

# nuke it
rm -rf build

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; build directory removed. Not rebuilding."
    exit 0
fi

## The real guard: plain Git-for-Windows bash vs. git-sdk-64. Both report
## as MINGW64/MSYS under uname, so that alone cannot tell them apart.
## What actually distinguishes them is whether the MSYS2 build tools this
## script depends on are present -- plain Git-for-Windows bash's minimal
## MSYS2 root never populates these, no matter how PATH is configured.
## Skipped above for --clean-only since cleaning doesn't need any of
## these tools.
MissingTool="no"
for tool in /usr/bin/cmake /usr/bin/make; do
    if [ ! -x "$tool" ]; then
        echo "Required tool not found or not executable: $tool"
        MissingTool="yes"
    fi
done
if [ "$MissingTool" = "yes" ]; then
    echo
    echo "This usually means you are running plain Git-for-Windows bash"
    echo "instead of git-sdk-64. These tools are NOT installable the same"
    echo "way in plain Git-for-Windows bash -- its bundled pacman (if any)"
    echo "is restricted to Git's own self-update, not general packages."
    echo
    echo "Install git-sdk-64 instead:"
    echo "  https://github.com/git-for-windows/build-extra/releases"
    echo "Then, from within git-sdk-64's shell:"
    echo "  pacman -Syu mingw-w64-x86_64-cmake mingw-w64-x86_64-make"
    exit 1
fi

if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then
    echo "arm-none-eabi-gcc not found on PATH."
    echo "See ../../SETUP.md for ARM GCC toolchain setup."
    exit 1
fi

# generate makefiles via cmake
MSYSTEM=MSYS /usr/bin/cmake -S . -B build -G "Unix Makefiles" \
  -DCMAKE_SYSTEM_NAME=Generic \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER=arm-none-eabi-gcc

# now, build it.
MSYSTEM=MSYS /usr/bin/make ${USE_VERBOSE} -C build -j
