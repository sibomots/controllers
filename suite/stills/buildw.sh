#!/usr/bin/env bash
#  ============================================================================
#  Stills -- NUCLEO-F767ZI bare-metal C minimal example.
#
#  Copyright (c) 2026 Jeff Wandling
#  All Rights Reserved.
#
#  Licensed under BSD 3-Clause
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted under the terms of the BSD 3-Clause license.
#  See the LICENSE file for the full text.
#  ============================================================================

printHelp() {
   cat <<EOM
BUILDW                    Stills (F767ZI) C Build Script (Windows / git-sdk-64)

NAME
    buildw.sh

SYNOPSIS

    buildw.sh [ --help ]
    buildw.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Configures (via CMake) and builds Stills, cross-compiling via
    arm-none-eabi-gcc. No C++ toolchain needed.

    Windows only (git-sdk-64 shell). There is no Linux-native flavor
    of this script -- use build.sh for that.

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

BUILDW                    Stills (F767ZI) C Build Script (Windows / git-sdk-64)
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

case "$(uname -s)" in
    MINGW*|MSYS*)
        : # good, keep going
        ;;
    *)
        echo "This does not look like a Windows git-bash shell (uname: $(uname -s))."
        echo "This build is Windows-only -- see the DESCRIPTION in --help, or use build.sh."
        exit 1
        ;;
esac

set -e

rm -rf build

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; build directory removed. Not rebuilding."
    exit 0
fi

MissingTool="no"
for tool in cmake make arm-none-eabi-gcc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found on PATH: $tool"
        MissingTool="yes"
    fi
done
if [ "$MissingTool" = "yes" ]; then
    echo "Install cmake, make, and the ARM GNU toolchain, then retry."
    exit 1
fi

cmake -S . -B build -G "Unix Makefiles" \
  -DCMAKE_SYSTEM_NAME=Generic \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER=arm-none-eabi-gcc

make ${USE_VERBOSE} -C build -j
