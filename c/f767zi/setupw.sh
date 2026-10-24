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
SETUP                    Dev Board Controller

NAME
    setup.sh

SYNOPSIS

    setup [ --help ]

    setup    [ -S | --speed SPEED ]
             [ -P | --port GDB_SERVER_PORT_NUMBER ]
             [ -d | --debug [ -i | --image IMAGE_FILE ] 
             [ -g | --gdb DEBUGGER ] ]

    Server Mode vs Debug Mode
    setup [ -s | --server ] | [ -d | --debug ]

DESCRIPTION
        
    This shell script helps the user setup the target for debugging.

    There are options to:

         Server Mode:

             - initiate a debug-server (GBDServer) for the debugging session.

         Client Mode:

             - initiate the gdb client connecting to the gdb server.

OPTIONS

     Defaults:

          -S 2000
          -P 2331
          -i image.elf
          -g `which arm-none-eabi-gdb`
      
     Generic

     --help    Output this manual page


     -P | --port     Set the GDBServer Listen port number.

     -S | --speed    Set the clock speed of the adapter.

     Files

     -i | --image  Set the filename of the image being debugged.

                   This will affect the flashing or any other 
                   command that is involved with the file.  For
                   example, if --image FILE is used, then that FILE
                   will be flashed if --flash is applied and that FILE
                   will be used if --debug is applied.
 
     Debugging
    
     -g | --gdb DEBUGGER

                   If a different 'gdb' program is needed, use this option
                   to specify the path to the gdb needed.  This has the 
                   effect of running DEBUGGER instead of the default
                   arm-none-eabi-gdb.
                   

     -s | --server Cause the invocation of the GDBServer on the host
                   system to connect to the target device and be
                   ready to accept gdb commands from the user debug
                   software (gdb)

     -d | --debug  Cause the invocation of the GDB client on the host.
                   This client will be prescribed to connect to the
                   gdb server.


ENVIRONMENT VARIABLES

    If the program 'setup' is not found in your path, add it to your path:

    $ export PATH=.:\$PATH

    That prepends the current directory to your \$PATH


DEPENDENCIES

      This script expects that the host system has the following 
      packages installed:

      REQUIRED:

         OpenOCD
         ARM GCC Toolchain

SETUP                    Dev Board Controller
EOM
}


## MAIN 

if [ $# -lt 1 ]; then
    printHelp
    exit 0
fi

Mode="none"
GDB=$(which arm-none-eabi-gdb)
# Default iamge file, TBD
S_DEBUG_IMAGE="image.elf"
# debug port for gdb-server
S_DEBUG_SERVER_PORT="2331"
# 2 Mhz
S_DEBUG_SPEED="2000"
# hard set for openocd
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

## Test if tools are present.

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
           echo "The gdb tool is part of the ARM GNU toolkit"
           echo "Did you download and install it?"
           exit 1
       fi
       if [ -z "${S_DEBUG_IMAGE}" ]; then
          if [ "${USING_CMD_IMAGE}" -eq "set" ]; then
           echo "WARNING: the debug image ${S_DEBUG_IMAGE} is NOT FOUND. Check command line."
           exit 0
          fi
       else
          if [ ! -f "${S_DEBUG_IMAGE}" ]; then
           echo "WARNING: the debug image ${S_DEBUG_IMAGE} is NOT FOUND. Check command line."
          fi
       fi 
       ## Used with SAM V71 Ultra (Atmel/Microchip)
       ##${GDB} -ex "target extended-remote localhost:${S_DEBUG_SERVER_PORT}"  -ex "file ${S_DEBUG_IMAGE}" -ex "load" -ex "sym ${S_DEBUG_IMAGE}" -ex "b main"
       ${GDB} -q ${S_DEBUG_IMAGE} -ex "target extended-remote :${S_DEBUG_SERVER_PORT}"
          exit 0
       ;;
       *)
            echo "Error:  No mode was selected."
            echo "Missing option of --debug OR --server.  PICK ONE"
       ;;
esac

