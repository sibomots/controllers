#!/usr/bin/env bash
#  ============================================================================
#  This file is part of samv71-tiny
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
BUILD                     samv71-tiny Ada Build Script (native Linux)

NAME
    build.sh

SYNOPSIS

    build.sh [ --help ]
    build.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds the Ada port of samv71-tiny via gprbuild (samv71_tiny.gpr),
    targeting arm-eabi with the light-tasking-samv71 runtime (AdaCore's
    bb-runtimes BSP for the SAMV71 Xplained Ultra board).

    This is the native-Linux flavor. For Windows (git-sdk-64 flavor of
    Git-for-Windows bash), use buildw.sh instead.

    Requires a 32-bit ARM ("arm-eabi") GNAT bare-metal cross-compiler on
    PATH -- same GNAT-FSF-builds distribution as the Windows toolchain,
    just the Linux x86_64 build (gnat-arm-elf-x86_64-linux64-<version>),
    from https://github.com/alire-project/GNAT-FSF-builds/releases.
    Do NOT confuse this with an "aarch64-elf" toolchain -- that targets
    64-bit ARM (AArch64) and cannot produce code for this chip's
    Cortex-M7 (32-bit ARMv7E-M) core at all, nor does it carry the
    samv71 runtime profiles (checked: it doesn't).

    gprbuild itself does not need to come from the same place -- any
    gprbuild on PATH works (e.g. apt's "gprbuild" package); it's a
    generic build orchestrator, not tied to a specific compiler vendor
    or target.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (gprbuild -v)

    -c | --clean-only    Remove the build output directories and exit;
                         do not rebuild.

DEPENDENCIES

      REQUIRED (must be on PATH):

         gprbuild
         arm-eabi-gcc

BUILD                     samv71-tiny Ada Build Script (native Linux)
EOM
}

USE_VERBOSE=""
CleanOnly="no"

while [ $# -gt 0 ]
do
   key="$1"
   case $key in
       -v|--verbose)
       USE_VERBOSE="-v"
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

## Sanity: this is the native-Linux flavor. If we're actually running
## under an MSYS/MINGW shell (git-bash of either flavor), point at the
## right script instead of pressing on with the wrong assumptions.
case "$(uname -s)" in
    MINGW*|MSYS*)
        echo "This looks like a Windows git-bash shell (uname: $(uname -s))."
        echo "Use buildw.sh instead -- it is the git-sdk-64 flavor of this script."
        exit 1
        ;;
esac

set -e

# nuke it
rm -rf obj bin

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; obj/ and bin/ removed. Not rebuilding."
    exit 0
fi

## Dependency guard -- fail clearly rather than letting gprbuild produce
## a confusing error partway through. Skipped above for --clean-only.
MissingTool="no"
for tool in gprbuild arm-eabi-gcc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found on PATH: $tool"
        MissingTool="yes"
    fi
done
if [ "$MissingTool" = "yes" ]; then
    echo "See ../SETUP.md for toolchain setup."
    exit 1
fi

mkdir -p obj bin
gprbuild -P samv71_tiny.gpr ${USE_VERBOSE}
