#!/bin/bash
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
export PATH=$PATH:/c/arm/bin

printHelp() {
   cat  <<EOM
SETUP                    Bifrost (F767ZI) Debug Setup

NAME
    setupw.sh

SYNOPSIS

    setupw.sh [ --help ]

    setupw.sh [ -S | --speed SPEED ]
             [ -P | --port GDB_SERVER_PORT_NUMBER ]
             [ -d | --debug [ -i | --image IMAGE_FILE ]
             [ -g | --gdb DEBUGGER ] ]

    Server Mode vs Debug Mode
    setupw.sh [ -s | --server ] | [ -d | --debug ]

DESCRIPTION

    Same OpenOCD/ST-Link debug chain as ../f722ze-tiny's own setupw.sh
    -- byte-identical in every way that matters (OpenOCD doesn't care
    what compiler produced the ELF it's flashing, and NUCLEO-F767ZI
    uses the same on-board ST-Link as NUCLEO-F722ZE) -- including using
    the stock installed target/stm32f7x.cfg unmodified. An earlier
    version of this script pointed at a local override of that file,
    added to work around what looked like a wrong auto-probed flash
    bank size (512KB reported instead of the real 2MB). That override
    turned out to change nothing (confirmed by testing it directly),
    and isn't needed: OpenOCD's own stm32f2x driver already has
    erratum-aware handling for this exact part family, visible directly
    in the server log on a clean connect --
        Info : device id = 0x10016451
        Info : ignoring flash probed value, using configured bank size
        Info : Single Bank 2048 kiB STM32F76x/77x found
    -- it recognizes this device ID and substitutes the known-correct
    2048KiB itself, no TCL-level configuration involved. The 512KB
    misreads trace back to that first "device id" read coming back bad
    on some connection attempts: when that happens, OpenOCD never
    recognizes the part as the erratum-affected F76x/77x family and
    skips the correction entirely, falling back to treating it as
    whatever a generic/unrecognized part would report.

    Takeaway if this shows up again: if "monitor flash banks" ever
    reports 0x00080000 instead of 0x00200000 for the main bank, don't
    chase it as a config problem -- connect once via
    "telnet localhost 4444" (while the server from -s is running) and
    run "flash info 0" to force a real re-probe, then retry from gdb.

    There are options to:

         Server Mode:

             - initiate a debug-server (GDBServer) for the debugging session.

         Client Mode:

             - initiate the gdb client connecting to the gdb server.

OPTIONS

     Defaults:

          -S 2000
          -P 2331
          -i bin/bifrost.elf
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
         arm-none-eabi-gdb), see ../SETUP.md

SETUP                    Bifrost (F767ZI) Debug Setup
EOM
}


## MAIN

if [ $# -lt 1 ]; then
    printHelp
    exit 0
fi

Mode="none"
# Prefer arm-none-eabi-gdb (the official ARM GNU Toolchain build, same one
# the C side uses -- see ../SETUP.md) over arm-eabi-gdb (the one bundled
# with the GNAT-FSF archive). If both are on PATH, the GNAT-bundled one
# was being picked up here by accident -- confirmed to lack libexpat/XML
# support ("Can not parse XML target description/memory map"), which
# breaks more than cosmetic register display: gdb's "load" command needs
# the XML memory map to know an address range is flash and route the
# write through the real flash-programming algorithm instead of a plain
# memory write, which silently does nothing to actual flash content.
GDB=$(which arm-none-eabi-gdb 2>/dev/null || which arm-eabi-gdb 2>/dev/null)
S_DEBUG_IMAGE="bin/bifrost.elf"
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
          export OPENOCD_SCRIPTS=/mingw64/share/openocd/scripts
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
           echo "Did you download and install it? See ../SETUP.md"
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
