#!/usr/bin/env bash
#  ============================================================================
#  This file is part of Crosby -- see crosby.gpr's own header.
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
BUILDW                    Crosby (F767ZI) Ada Build Script (Windows / git-sdk-64)

NAME
    buildw.sh

SYNOPSIS

    buildw.sh [ --help ]
    buildw.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds Crosby, the minimal bare-metal Ada LED-blink example for
    NUCLEO-F767ZI, via gprbuild (crosby.gpr), targeting arm-eabi with
    the light-stm32f769disco runtime (non-tasking -- see crosby.gpr's
    own header for why).

    Requires the standalone GNAT-FSF ARM ELF toolchain + gprbuild
    (direct archive downloads, not Alire) -- same toolchain as every
    other Ada port in this repo, see ../../ada/SETUP.md for setup.

    No ../../ada/f767zi-style one-time runtime-overrides step is
    needed here -- this program makes no timing claim the runtime's
    un-overridden clock bring-up could get wrong; see crosby.gpr.

    Windows only (git-sdk-64 shell), same as the other Ada ports' own
    buildw.sh. There is no Linux-native flavor of this script -- use
    build.sh for that.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (gprbuild -v)

    -c | --clean-only    Remove the build output directories and exit;
                         do not rebuild.

DEPENDENCIES

      REQUIRED (must be on PATH):

         gprbuild
         arm-eabi-gcc

      If arm-eabi-gcc isn't the right name for what you actually have
      installed, check the toolchain's own bin/ directory -- see
      ../../ada/SETUP.md (toolchain PATH setup).

BUILDW                    Crosby (F767ZI) Ada Build Script (Windows / git-sdk-64)
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

## Sanity: are we even in some flavor of git-bash at all?
case "$(uname -s)" in
    MINGW*|MSYS*)
        : # good, keep going
        ;;
    *)
        echo "This does not look like a Windows git-bash shell (uname: $(uname -s))."
        echo "This Ada build is Windows-only -- see the DESCRIPTION in --help."
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
    echo "See ../../ada/SETUP.md for toolchain setup."
    exit 1
fi

mkdir -p obj bin

gprbuild -P crosby.gpr ${USE_VERBOSE}
