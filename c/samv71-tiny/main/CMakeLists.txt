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
##
##  CMake conversion of the m7 (SAMV71) controller firmware, modeled
##  directly on c/bifrost/CMakeLists.txt -- same component() function
##  shape, same add_subdirectory/global-link pattern. Two adaptations
##  for this project specifically:
##
##  1. Components here use include/ (matching this tree's existing
##     layout throughout hal/hpl/hri/vendor/etc.), not inc/ like
##     bifrost -- changing that would mean renaming directories inside
##     vendor/, which stays untouched.
##
##  2. The final link wraps all component libraries in
##     -Wl,--start-group/--end-group, extending the same trick
##     defs.mk already used for -lm/-lc. The original Makefile linked
##     plain .o files (no archive, no ordering sensitivity); this
##     component model uses real static libraries, and this tree's
##     component dependency graph is denser/more circular than
##     bifrost's (nearly everything touches hal/hal, hal/utils, hri,
##     hpl/pio, hpl/pmc), so GNU ld's archive-ordering sensitivity is a
##     real risk here that bifrost's simpler layered graph didn't have.
##
##  Phase B complete: hal/, hpl/, and hri/ are gone. Their actually-used
##  logic (confirmed by tracing real call chains, not assumed from
##  Makefile INCDIRS alone -- hpl/core's PLL/clock-tree setup looked
##  unused by that measure but very much wasn't) was hand-ported into
##  lowlevel/. vendor/ (CMSIS + the SAMV71 DFP) remains the one real
##  dependency -- register/core definitions, not driver logic. The
##  component graph is much smaller now (lowlevel/startup/rtbus/
##  tinymon/app), closer to bifrost's own layered simplicity -- the
##  --start-group/--end-group wrap below is kept anyway as a low-cost
##  precaution, not because it's known to still be load-bearing.
cmake_minimum_required(VERSION 3.21)
project(m7 LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)

# Flags preserved exactly from defs.mk -- not new assumptions. Notably:
# no -mfpu/-mfloat-abi (software float, unlike samv71-squeaky), and
# --specs=nano.specs only (no --specs=nosys.specs -- this tree provides
# its own syscall stubs via hal/utils/src/utils_syscalls.c).
add_compile_options(-mcpu=cortex-m7 -mthumb -Wall -Og -g3 -funsigned-char -std=gnu99 -DDEBUG -D__SAMV71Q21B__)
add_link_options(-mcpu=cortex-m7 -mthumb --specs=nano.specs -Wl,--gc-sections)

function(m7_component name type)
if("${type}" STREQUAL "INTERFACE")
add_library(${name} INTERFACE)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
set_property(GLOBAL APPEND PROPERTY M7_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include")
endif()
target_include_directories(${name} INTERFACE include)
else()
set(_srclist "")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src")
aux_source_directory(src _srclist)
endif()
if(_srclist STREQUAL "")
add_library(${name} INTERFACE)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
set_property(GLOBAL APPEND PROPERTY M7_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include")
endif()
target_include_directories(${name} INTERFACE include)
else()
	add_library(${name} STATIC ${_srclist})
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
set_property(GLOBAL APPEND PROPERTY M7_INC_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include")
endif()
target_include_directories(${name} PUBLIC include)
endif()
endif()
set_property(GLOBAL APPEND PROPERTY M7_COMPONENTS ${name})
endfunction()

# CMake's directory-scope include_directories() only flows FORWARD to
# subdirectories added via add_subdirectory() *after* the call -- it
# does not reach back into ones already processed. (Confirmed the hard
# way: a first version of this file called include_directories() once,
# at the bottom, after every add_subdirectory() -- real build, real
# toolchain, real "samv71q21b.h: No such file or directory" errors.)
# So: vendor/ goes in first, before anything needs it, and lowlevel/'s
# own include/ gets collected and applied right after lowlevel is
# processed, before any of the components that need it (rtbus/
# tinymon/app) are added.

# vendor/ was never a Makefile component (no Makefile in it) -- always
# just a bare include path. config/include/ is gone (Phase B) -- it
# held only Atmel-Start-generated parameters for hal/hpl, nothing
# outside those directories ever included it directly.
include_directories(
  ${CMAKE_SOURCE_DIR}/vendor/atmel/SAMV71_DFP/2.4.182/samv71b/include
  ${CMAKE_SOURCE_DIR}/vendor/CMSIS/5.4.0/CMSIS/Core/include
)

add_subdirectory(lowlevel)

get_property(_incs GLOBAL PROPERTY M7_INC_DIRS)
list(REMOVE_DUPLICATES _incs)
if(_incs)
include_directories(${_incs})
endif()

add_subdirectory(startup)
add_subdirectory(rtbus)

# Same forward-only propagation rule applies one level further out:
# tinymon needs rtbus's include/ (rtpacket.h/cmd_handler.h/tm_parse.h),
# so re-collect+apply before adding it -- and app, after tinymon, needs
# both rtbus's and tinymon's.
get_property(_incs GLOBAL PROPERTY M7_INC_DIRS)
list(REMOVE_DUPLICATES _incs)
if(_incs)
include_directories(${_incs})
endif()

add_subdirectory(tinymon)

get_property(_incs GLOBAL PROPERTY M7_INC_DIRS)
list(REMOVE_DUPLICATES _incs)
if(_incs)
include_directories(${_incs})
endif()

add_subdirectory(app)

add_executable(m7 app/src/main.c)
set_target_properties(m7 PROPERTIES SUFFIX ".elf" OUTPUT_NAME "image")

get_property(_comps GLOBAL PROPERTY M7_COMPONENTS)
target_link_libraries(m7 PRIVATE -Wl,--start-group ${_comps} -lm -lc -Wl,--end-group)

set(M7_LD_DEFAULT "${CMAKE_SOURCE_DIR}/startup/samv71q21b_flash.ld")
set(M7_LD "${M7_LD_DEFAULT}" CACHE FILEPATH "Linker script for ATSAMV71Q21B")

if(NOT EXISTS "${M7_LD}")
message(FATAL_ERROR "Linker script not found: ${M7_LD}
Hint: put it at ${M7_LD_DEFAULT} or pass -DM7_LD=/path/to/your.ld")
endif()

# --undefined=Reset_Handler forces the linker to resolve that symbol,
# which pulls in startup_samv71q21b.o from libm7_startup.a even though
# nothing in the C-level call graph references it (the CPU hardware
# calls it, invisibly to the linker) -- without this, the whole object
# (Reset_Handler AND the .vectors-section exception_table alongside
# it) gets excluded by archive-member selection *before* the linker
# script's KEEP(*(.vectors)) ever gets a chance to protect it, and
# --gc-sections then has nothing to garbage-collect because nothing
# of the real application was ever linked in to begin with. Confirmed
# the hard way: a first real build (real toolchain) linked clean and
# produced a 172-byte image.elf with no .vectors section, no
# Reset_Handler, no main, nothing but C-runtime boilerplate -- not a
# syntax problem, a static-library-vs-plain-.o linking difference the
# original Makefile build never had to deal with. Not modifying the
# linker script or the vendor-origin startup file -- fixed purely at
# the link-flags level.
target_link_options(m7 PRIVATE
-T "${M7_LD}"
-Wl,-Map,image.map
-Wl,--gc-sections
-Wl,--undefined=Reset_Handler
)

if(NOT CMAKE_OBJCOPY)
find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
endif()
add_custom_command(TARGET m7 POST_BUILD
COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:m7> ${CMAKE_CURRENT_BINARY_DIR}/image.bin
)
