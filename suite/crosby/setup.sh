#!/bin/bash
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
   cat  <<EOM
SETUP                     Crosby (F767ZI) Debug Setup (native Linux)

NAME
    setup.sh

SYNOPSIS

    setup.sh [ --help ]

    setup.sh [ -S | --speed SPEED ]
             [ -P | --port GDB_SERVER_PORT_NUMBER ]
             [ -d | --debug [ -i | --image IMAGE_FILE ]
             [ -g | --gdb DEBUGGER ] ]

    Server Mode vs Debug Mode
    setup.sh [ -s | --server ] | [ -d | --debug ]

DESCRIPTION

    Native-Linux counterpart of setupw.sh -- same OpenOCD/ST-Link
    debug chain, same stock target/stm32f7x.cfg, no local overrides.
    For Windows (git-sdk-64), use setupw.sh instead.

    There are options to:

         Server Mode:

             - initiate a debug-server (GDBServer) for the debugging session.

         Client Mode:

             - initiate the gdb client connecting to the gdb server.

OPTIONS

     Defaults:

          -S 2000
          -P 2331
          -i bin/crosby.elf
          -g \`which arm-none-eabi-gdb\`

     Generic

     --help    Output this manual page


     -P | --port     Set the GDBServer Listen port number.

     -S | --speed    Set the clock speed of the adapter.

     Files

     -i | --image  Set the filename of the image being debugged.

     Debugging

     -g | --gdb DEBUGGER

                   If a different 'gdb' program is needed, use this option
                   to specify the path to the gdb needed.

     -s | --server Cause the invocation of the GDBServer on the host
                   system to connect to the target device.

     -d | --debug  Cause the invocation of the GDB client on the host.


DEPENDENCIES

      REQUIRED:

         OpenOCD
         GNAT bare-metal ARM ELF toolchain (arm-eabi-gdb or
         arm-none-eabi-gdb), see ../../ada/SETUP.md

SETUP                     Crosby (F767ZI) Debug Setup (native Linux)
EOM
}


## MAIN

## Sanity: this is the native-Linux flavor.
case "$(uname -s)" in
    MINGW*|MSYS*)
        echo "This looks like a Windows git-bash shell (uname: $(uname -s))."
        echo "Use setupw.sh instead -- it is the git-sdk-64 flavor of this script."
        exit 1
        ;;
esac

if [ $# -lt 1 ]; then
    printHelp
    exit 0
fi

Mode="none"
# Prefer arm-none-eabi-gdb over arm-eabi-gdb -- same reasoning as
# setupw.sh: the GNAT-bundled one lacks libexpat/XML support, which
# breaks gdb's "load" command silently (writes land as plain memory
# writes instead of routing through real flash programming) rather
# than with an obvious error.
GDB=$(which arm-none-eabi-gdb 2>/dev/null || which arm-eabi-gdb 2>/dev/null)
S_DEBUG_IMAGE="bin/crosby.elf"
S_DEBUG_SERVER_PORT="2331"
S_DEBUG_SPEED="2000"
GDBSERVER=$(which openocd)

while [ $# -gt 0 ]
do
   key="$1"
   case $key in
       -S|--speed)
          shift;
          S_DEBUG_SPEED="$1"
          shift
       ;;
       -P|--port)
          shift;
          S_DEBUG_SERVER_PORT="$1"
          shift;
       ;;
       -g|--gdb)
          shift
          GDB="$1"
          shift
          echo "Using debugger: ${GDB}"
          ;;
       -i|--image)
       shift
       image="$1"
       shift
       S_DEBUG_IMAGE="$image"
       echo "Using image $S_DEBUG_IMAGE"
       USING_CMD_IMAGE="set"
       ;;
       -s|--server)
       Mode="server"
       shift
       ;;
       -d|--debug)
       Mode="client"
       shift
       ;;
       -h|--help)
       printHelp
       shift
       ;;
       *)
           echo "Unknown option: $key"
           shift
   esac
done

case $Mode in
       server)
          if [ ! -x "$GDBSERVER" ]; then
              echo "${GDBSERVER} is not installed.  View manual page."
              exit 1
          fi
          ${GDBSERVER} -f interface/stlink.cfg -f target/stm32f7x.cfg \
        -c "adapter speed ${S_DEBUG_SPEED}" \
        -c "transport select hla_swd" \
        -c "gdb_port ${S_DEBUG_SERVER_PORT}"

          exit 0
       ;;
       client)
       if [ ! -x "$GDB" ]; then
           echo "Cannot locate GDB-client.  Check usage."
           echo "Check you set PATH for where you stored your gdb"
           echo "Did you download and install it? See ../../ada/SETUP.md"
           exit 1
       fi
       if [ ! -f "${S_DEBUG_IMAGE}" ]; then
           echo "WARNING: the debug image ${S_DEBUG_IMAGE} is NOT FOUND. Check command line."
       fi
       ${GDB} -q ${S_DEBUG_IMAGE} -ex "target extended-remote :${S_DEBUG_SERVER_PORT}"
          exit 0
       ;;
       *)
            echo "Error:  No mode was selected."
            echo "Missing option of --debug OR --server.  PICK ONE"
       ;;
esac
