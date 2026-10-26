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
BUILD                     Bifrost (F767ZI) Ada Build Script (native Linux)

NAME
    build.sh

SYNOPSIS

    build.sh [ --help ]
    build.sh [ -v | --verbose ] [ -c | --clean-only ]

DESCRIPTION

    Builds the tasking-phase Ada port of Bifrost for NUCLEO-F767ZI via
    gprbuild (bifrost.gpr), targeting arm-eabi with the
    light-tasking-stm32f769disco runtime.

    This is the native-Linux flavor. For Windows (git-sdk-64 flavor of
    Git-for-Windows bash), use buildw.sh instead.

    Same one-time runtime-overrides/README.md step as buildw.sh's
    DESCRIPTION covers -- NUCLEO-F767ZI's actual 8MHz HSE has to be
    installed into whichever toolchain install actually builds this
    (the Linux one, for this script) before Setup_Pll's clock bring-up
    will be correct.

OPTIONS

    -h | --help          Output this manual page

    -v | --verbose       Verbose build output (gprbuild -v)

    -c | --clean-only    Remove the build output directories and exit;
                         do not rebuild.

DEPENDENCIES

      REQUIRED (must be on PATH):

         gprbuild
         arm-eabi-gcc

BUILD                     Bifrost (F767ZI) Ada Build Script (native Linux)
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
rm -f lowlevel/src/bifrost-net-config.ads lowlevel/src/bifrost_net_config.h

if [ "$CleanOnly" = "yes" ]; then
    echo "Clean-only requested; obj/, bin/, and the generated net config removed. Not rebuilding."
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

## Build-time network config -- see net.conf and gen_net_config.sh.
## Regenerated on every build; lowlevel/src/bifrost-net-config.ads and
## bifrost_net_config.h are build artifacts (gitignored), never
## hand-edited directly.
bash gen_net_config.sh net.conf

gprbuild -P bifrost.gpr ${USE_VERBOSE}
