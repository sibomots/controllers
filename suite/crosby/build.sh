#!/usr/bin/env bash
#  ============================================================================
#  Crosby -- NUCLEO-F767ZI bare-metal Ada minimal example.
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
BUILD                     Crosby (F767ZI) Ada Build Script (native Linux)

NAME
    build.sh

SYNOPSIS

    build.sh [ --help ]
    build.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds Crosby via gprbuild (crosby.gpr), targeting arm-eabi with
    the light-stm32f769disco runtime.

    This is the native-Linux flavor. For Windows (git-sdk-64 flavor of
    Git-for-Windows bash), use buildw.sh instead.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (gprbuild -v)

    -c | --clean-only    Remove the build output directories and exit;
                         do not rebuild.

DEPENDENCIES

      REQUIRED (must be on PATH):

         gprbuild
         arm-eabi-gcc

BUILD                     Crosby (F767ZI) Ada Build Script (native Linux)
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

## Sanity: this is the native-Linux flavor.
case "$(uname -s)" in
    MINGW*|MSYS*)
        echo "This looks like a Windows git-bash shell (uname: $(uname -s))."
        echo "Use buildw.sh instead -- it is the git-sdk-64 flavor of this script."
        exit 1
        ;;
esac

set -e

rm -rf obj bin

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; obj/ and bin/ removed. Not rebuilding."
    exit 0
fi

MissingTool="no"
for tool in gprbuild arm-eabi-gcc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found on PATH: $tool"
        MissingTool="yes"
    fi
done
if [ "$MissingTool" = "yes" ]; then
    echo "Install the GNAT ARM ELF toolchain and gprbuild, then retry."
    exit 1
fi

mkdir -p obj bin

gprbuild -P crosby.gpr ${USE_VERBOSE}
