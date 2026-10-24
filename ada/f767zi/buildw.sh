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
BUILDW                    Bifrost (F767ZI) Ada Build Script (Windows / git-sdk-64)

NAME
    buildw.sh

SYNOPSIS

    buildw.sh [ --help ]
    buildw.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds the tasking-phase Ada port of Bifrost for NUCLEO-F767ZI via
    gprbuild (bifrost.gpr), targeting arm-eabi with the
    light-tasking-stm32f769disco runtime.

    Requires the standalone GNAT-FSF ARM ELF toolchain + gprbuild
    (direct archive downloads, not Alire) -- same toolchain as
    ../f722ze-tiny and ../samv71-tiny, see ../SETUP.md for setup.

    One extra one-time step beyond ../SETUP.md, specific to this board:
    see runtime-overrides/README.md -- NUCLEO-F767ZI's actual 8MHz HSE
    has to be installed into the toolchain's own runtime before the
    clock bring-up this runtime does automatically (Setup_Pll) will
    compute the right PLL configuration. Skipping that step is not a
    build error -- the board just comes up at the wrong clock, silently.

    Windows only (git-sdk-64 shell), same as the other two Ada ports'
    own buildw.sh. There is no Linux-native flavor of this script.

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
      ../SETUP.md (toolchain PATH setup).

BUILDW                    Bifrost (F767ZI) Ada Build Script (Windows / git-sdk-64)
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
    echo "See ../SETUP.md for toolchain setup."
    exit 1
fi

mkdir -p obj bin
gprbuild -P bifrost.gpr ${USE_VERBOSE}
