#!/bin/bash
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
   cat  <<EOM
SETUP                     Stills (F767ZI) Debug Setup (native Linux)

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

    Native-Linux OpenOCD/ST-Link debug chain for NUCLEO-F767ZI. For
    Windows (git-sdk-64), use setupw.sh instead.

OPTIONS

     Defaults:

          -S 2000
          -P 2331
          -i build/stills.elf
          -g \`which arm-none-eabi-gdb\`

     --help    Output this manual page

     -P | --port     Set the GDBServer Listen port number.
     -S | --speed    Set the clock speed of the adapter.
     -i | --image    Set the filename of the image being debugged.
     -g | --gdb DEBUGGER   If a different 'gdb' is needed, specify the path.
     -s | --server   Invoke the GDBServer on the host to connect to the target.
     -d | --debug    Invoke the GDB client on the host.

DEPENDENCIES

      REQUIRED:

         OpenOCD
         arm-none-eabi-gdb

SETUP                     Stills (F767ZI) Debug Setup (native Linux)
EOM
}

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
GDB=$(which arm-none-eabi-gdb 2>/dev/null)
S_DEBUG_IMAGE="build/stills.elf"
S_DEBUG_SERVER_PORT="2331"
S_DEBUG_SPEED="2000"
GDBSERVER=$(which openocd)

while [ $# -gt 0 ]
do
   key="$1"
   case $key in
       -S|--speed) shift; S_DEBUG_SPEED="$1"; shift ;;
       -P|--port) shift; S_DEBUG_SERVER_PORT="$1"; shift ;;
       -g|--gdb) shift; GDB="$1"; shift; echo "Using debugger: ${GDB}" ;;
       -i|--image) shift; S_DEBUG_IMAGE="$1"; shift; echo "Using image $S_DEBUG_IMAGE" ;;
       -s|--server) Mode="server"; shift ;;
       -d|--debug) Mode="client"; shift ;;
       -h|--help) printHelp; shift ;;
       *) echo "Unknown option: $key"; shift ;;
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
