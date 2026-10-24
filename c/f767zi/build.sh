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
BUILD                     Bifrost Build Script (native Linux)

NAME
    build.sh

SYNOPSIS

    build.sh [ --help ]
    build.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    This shell script configures (via CMake) and builds the Bifrost
    application, cross-compiling for the ARM target via the
    arm-none-eabi-gcc toolchain.

    This is the native-Linux flavor. For Windows (git-sdk-64 flavor of
    Git-for-Windows bash), use buildw.sh instead.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (make VERBOSE=1)

    -c | --clean-only    Remove the build directory and exit; do not
                         reconfigure or rebuild.

DEPENDENCIES

      REQUIRED (must be on PATH):

         cmake
         make
         arm-none-eabi-gcc
         arm-none-eabi-g++

BUILD                     Bifrost Build Script (native Linux)
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
rm -rf build

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; build directory removed. Not rebuilding."
    exit 0
fi

## Dependency guard -- fail clearly and early rather than letting cmake
## or make produce a confusing error partway through. Skipped above for
## --clean-only since cleaning doesn't need any of these tools.
MissingTool="no"
for tool in cmake make arm-none-eabi-gcc arm-none-eabi-g++; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found on PATH: $tool"
        MissingTool="yes"
    fi
done
if [ "$MissingTool" = "yes" ]; then
    echo "See ../SETUP.md for toolchain setup."
    exit 1
fi

# generate makefiles via cmake
cmake -S . -B build -G "Unix Makefiles" \
  -DCMAKE_SYSTEM_NAME=Generic \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER=arm-none-eabi-gcc \
  -DCMAKE_CXX_COMPILER=arm-none-eabi-g++

# now, build it.
make ${USE_VERBOSE} -C build -j
