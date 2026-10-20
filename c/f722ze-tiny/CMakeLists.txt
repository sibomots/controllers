##  ============================================================================
##  This file is part of Bifrost
## 
##  Copyright (c) 2025 Jeff Wandling
##  All Rights Reserved.
## 
##  Licensed under BSD 3-Clause
##  Redistribution and use in source and binary forms, with or without
##  modification, are permitted under the terms of the BSD 3-Clause license.
##  See the LICENSE file for the full text.
##  ============================================================================
cmake_minimum_required(VERSION 3.21)
project(bifrost LANGUAGES C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)

add_compile_options(-g -mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard -ffunction-sections -fdata-sections -ffreestanding -fno-builtin)
add_link_options(-mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs -lc -lm -lnosys)

function(bifrost_component name type)
if("${type}" STREQUAL "INTERFACE")
add_library(${name} INTERFACE)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
set_property(GLOBAL APPEND PROPERTY BIFROST_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
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
set_property(GLOBAL APPEND PROPERTY BIFROST_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
endif()
target_include_directories(${name} INTERFACE inc)
else()
	add_library(${name} STATIC ${_srclist})
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
set_property(GLOBAL APPEND PROPERTY BIFROST_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/inc")
endif()
target_include_directories(${name} PUBLIC inc)
endif()
endif()
set_property(GLOBAL APPEND PROPERTY BIFROST_COMPONENTS ${name})
endfunction()

add_subdirectory(config)
add_subdirectory(lowlevel)
add_subdirectory(behavioral)
add_subdirectory(behavioral/calc)
add_subdirectory(behavioral/client)
add_subdirectory(interfaces)
add_subdirectory(app)

get_property(_incs GLOBAL PROPERTY BIFROST_INC_DIRS)
list(REMOVE_DUPLICATES _incs)
if(_incs)
include_directories(${_incs})
endif()

add_executable(bifrost app/src/main.c)
target_link_libraries(bifrost_behavioral PRIVATE bifrost_lowlevel)
target_link_libraries(bifrost_app PRIVATE bifrost_behavioral)

set_target_properties(bifrost PROPERTIES SUFFIX ".elf")
get_property(_comps GLOBAL PROPERTY BIFROST_COMPONENTS)
target_link_libraries(bifrost PRIVATE ${_comps})

# Fine for this C target either way -- see HARDWARE.md at the repo root.
# NUCLEO-F767ZI also works and is the preferred board project-wide.
set(BIFROST_LD_DEFAULT "${CMAKE_SOURCE_DIR}/config/stm32f722ze.ld")
set(BIFROST_LD "${BIFROST_LD_DEFAULT}" CACHE FILEPATH "Linker script for STM32F722ZE")

get_property(_ld GLOBAL PROPERTY BIFROST_LINKER_SCRIPT)

if(NOT EXISTS "${BIFROST_LD}")
message(FATAL_ERROR "Linker script not found: ${BIFROST_LD}
Hint: put it at ${BIFROST_LD_DEFAULT} or pass -DBIFROST_LD=/path/to/your.ld")
endif()

target_link_options(bifrost PRIVATE
-T "${BIFROST_LD}"
-Wl,-Map,bifrost.map
-Wl,--gc-sections
-nostartfiles
-Wl,-e,Reset_Handler
)

if(NOT CMAKE_OBJCOPY)
find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
endif()
add_custom_command(TARGET bifrost POST_BUILD
COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:bifrost> ${CMAKE_CURRENT_BINARY_DIR}/bifrost.bin
)
