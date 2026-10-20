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
BUILDW                    Bifrost Ada Build Script (Windows / git-sdk-64)

NAME
    buildw.sh

SYNOPSIS

    buildw.sh [ --help ]
    buildw.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds the Ada port of Bifrost via gprbuild (bifrost.gpr), targeting
    arm-eabi with the light-cortex-m7f runtime.

    Requires the standalone GNAT-FSF ARM ELF toolchain + gprbuild
    (direct archive downloads, not Alire) -- see ../SETUP.md for setup.

    Windows only (git-sdk-64 shell), same as the C side's buildw.sh.
    There is no Linux-native flavor of this script: the toolchain was
    deliberately installed as standalone Windows archives, and there is
    no point verifying this particular build off-target.

    Board selection: bifrost.gpr's "Board" scenario variable picks
    which lowlevel/board/<name>/src directory gets built (register
    addresses, pin map), default "stm32f722ze" (what this project's
    current UART/LCD work was built and proven on -- NUCLEO-F767ZI is
    the preferred board for Ada going forward, see HARDWARE.md at the
    repo root, but has no board entry here yet). This script always
    builds the default; to target a different board, invoke gprbuild
    directly with -XBOARD=<name>, e.g.:
        gprbuild -P bifrost.gpr -XBOARD=stm32f722ze

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

BUILDW                    Bifrost Ada Build Script (Windows / git-sdk-64)
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
