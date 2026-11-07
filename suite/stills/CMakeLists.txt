##  ============================================================================
##  Stills -- NUCLEO-F767ZI bare-metal C minimal example.
##
##  Copyright (c) 2026 Jeff Wandling
##  All Rights Reserved.
##
##  Licensed under BSD 3-Clause
##  Redistribution and use in source and binary forms, with or without
##  modification, are permitted under the terms of the BSD 3-Clause license.
##  See the LICENSE file for the full text.
##  ============================================================================

## Per-directory CMakeLists.txt tree (config/lowlevel/app), each
## registering a component via stills_component() below. See
## DESIGN.md for why this program links with -nostdlib and no C++.
cmake_minimum_required(VERSION 3.21)
project(stills LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)

## Applied globally, before add_subdirectory, so every component
## picks these up.
add_compile_options(
    -g
    -mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard
    -ffunction-sections -fdata-sections
    -ffreestanding -fno-builtin
    -Wall -Wextra
)

add_link_options(
    -mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard
    -Wl,--gc-sections
    -nostdlib
)

## "type" is only ever checked against "INTERFACE" -- anything else
## (including the literal string "OBJECT" each subdirectory below
## passes) falls through to a plain STATIC library.
function(stills_component name type)
    if("${type}" STREQUAL "INTERFACE")
        add_library(${name} INTERFACE)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
            set_property(GLOBAL APPEND PROPERTY STILLS_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
        endif()
        target_include_directories(${name} INTERFACE inc)
    else()
        set(_srclist "")
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src")
            aux_source_directory(src _srclist)
        endif()
        if(_srclist STREQUAL "")
            add_library(${name} INTERFACE)
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
                set_property(GLOBAL APPEND PROPERTY STILLS_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
            endif()
            target_include_directories(${name} INTERFACE inc)
        else()
            add_library(${name} STATIC ${_srclist})
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
                set_property(GLOBAL APPEND PROPERTY STILLS_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
            endif()
            target_include_directories(${name} PUBLIC inc)
        endif()
    endif()
    set_property(GLOBAL APPEND PROPERTY STILLS_COMPONENTS ${name})
endfunction()

add_subdirectory(config)
add_subdirectory(lowlevel)
add_subdirectory(app)

get_property(_incs GLOBAL PROPERTY STILLS_INC_DIRS)
list(REMOVE_DUPLICATES _incs)
if(_incs)
    include_directories(${_incs})
endif()

add_executable(stills app/src/main.c)
target_link_libraries(stills_app PRIVATE stills_lowlevel)

set_target_properties(stills PROPERTIES SUFFIX ".elf")
get_property(_comps GLOBAL PROPERTY STILLS_COMPONENTS)
target_link_libraries(stills PRIVATE ${_comps})

target_link_options(stills PRIVATE
    -T "${CMAKE_SOURCE_DIR}/config/stm32f767zi.ld"
    -Wl,-Map,stills.map
    -Wl,-e,Reset_Handler
)

if(NOT CMAKE_OBJCOPY)
    find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
endif()
add_custom_command(TARGET stills POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:stills> ${CMAKE_CURRENT_BINARY_DIR}/stills.bin
)
