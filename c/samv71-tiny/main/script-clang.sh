#!/bin/bash
# Script to run clang-format on files modified for RTBus Prototype SW.
# Run on cygwin, make sure clang-format is installed.

clang-format.exe -i app/src/main.c
clang-format.exe -i rtbus/include/rtbus.h
clang-format.exe -i rtbus/include/rtpacket.h
clang-format.exe -i rtbus/include/cmd_handler.h
clang-format.exe -i rtbus/include/exec_cmd.h
clang-format.exe -i rtbus/src/rtbus.c
clang-format.exe -i rtbus/src/cmd_handler.c
clang-format.exe -i rtbus/src/exec_cmd.c
clang-format.exe -i lowlevel/include/atmel_start_pins.h
clang-format.exe -i lowlevel/include/tinymon.h
clang-format.exe -i lowlevel/src/board_init.c
