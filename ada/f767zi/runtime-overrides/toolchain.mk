# ============================================================================
# This file is part of Bifrost
#
# Copyright (c) 2025 Jeff Wandling
# All Rights Reserved.
#
# Licensed under BSD 3-Clause
# Redistribution and use in source and binary forms, with or without
# modification, are permitted under the terms of the BSD 3-Clause license.
# See the LICENSE file for the full text.
# ============================================================================

# One-time patch of the installed GNAT runtime for
# light-tasking-stm32f769disco, applying this directory's gnat_user/
# overrides permanently into the toolchain's own adalib/.
#
# Why this exists instead of a plain `cp`: gprbuild (unlike gnatmake)
# never recompiles predefined/runtime units on its own, even once a
# gnat_user override shadows one -- confirmed directly against both
# tools, not assumed. Left as just a file drop, every ordinary
# `gprbuild -P bifrost.gpr` would keep failing at bind ("X must be
# recompiled") forever, and neither `gprbuild -a` nor `gnatmake -P ... -a`
# help (the latter silently drops -a -- it's just a wrapper around
# gprbuild internally). This Makefile recompiles the whole affected
# dependency chain once, via classic, non-project `gnatmake -a` (the one
# tool that actually does this), then copies the results directly into
# the toolchain's adalib/ so every ordinary gprbuild build afterward
# just works, no special flags, same as f722ze-tiny/samv71-tiny's own
# builds.
#
# USAGE:
#   Edit GNAT_PREFIX below (or override on the command line) to point
#   at wherever the GNAT-FSF-builds ARM ELF archive was extracted --
#   see ../SETUP.md. Then, once, per machine:
#     $ make -f toolchain.mk
#   (Requires the real MSYS2-rooted `make` under git-sdk-64 on Windows,
#   same requirement ../../c/SETUP.md already notes for that shell --
#   plain Git-for-Windows bash doesn't provide it.)
#
# Safe to re-run -- re-running after editing gnat_user/ content (e.g. a
# future board-parameter tweak) just redoes the patch with the new
# content. Only ever touches light-tasking-stm32f769disco's own
# directory tree -- see README.md for why that doesn't affect
# f722ze-tiny (light-cortex-m7f) or samv71-tiny (light-tasking-samv71)
# at all.

# ---- EDIT THIS to match your machine ----------------------------------
# Windows (git-sdk-64), per ../SETUP.md's convention:
#   GNAT_PREFIX := /c/ada-arm/gnat-arm-elf-windows64-x86_64-<version>
# Native Linux:
#   GNAT_PREFIX := /opt/gnat-arm-elf-linux64-x86_64-<version>
GNAT_PREFIX := /opt/gnat-arm-elf-linux64-x86_64-15.3.0-1

# -------------------------------------------------------------------------

RTS_NAME := light-tasking-stm32f769disco
RTS_DIR  := $(GNAT_PREFIX)/arm-eabi/lib/gnat/$(RTS_NAME)

GNATMAKE := arm-eabi-gnatmake

# Absolute, no leading dot -- gnatmake's -D switch handled a dot-prefixed
# relative name (".rtsbuild") badly in practice (files scattered into
# CWD instead of being confined to it, confirmed by testing, not
# theorized), so this avoids both relative-path ambiguity and whatever
# that was.
BUILD_DIR := $(CURDIR)/rtsbuild_tmp

# Absolute -- the recipe below cd's into BUILD_DIR (see its own comment
# for why), so anything referencing project sources needs to survive
# that cd, not just assume CWD is still runtime-overrides/.
PROJECT_DIR := $(CURDIR)/..
SRC_DIRS := -I$(PROJECT_DIR)/lowlevel/src -I$(PROJECT_DIR)/behavioral/src -I$(PROJECT_DIR)/app/src
MAIN_FILE := $(PROJECT_DIR)/app/src/main.adb

# Same target CPU/FPU switches bifrost.gpr's Compiler package specifies --
# must match, or the recompiled runtime units won't agree with what the
# application itself is later compiled/linked with.
CPU_SWITCHES := -mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard

.PHONY: all patch clean

all: patch

patch:
	@test -d "$(RTS_DIR)/gnat_user" || { \
	  echo "ERROR: $(RTS_DIR)/gnat_user not found."; \
	  echo "Is GNAT_PREFIX set correctly? Currently: $(GNAT_PREFIX)"; \
	  exit 1; \
	}
	cp gnat_user/s-bbbopa.ads gnat_user/setup_pll.adb "$(RTS_DIR)/gnat_user/"
	mkdir -p $(BUILD_DIR)
	@echo "Recompiling the affected runtime dependency chain (classic gnatmake -a)..."
	@# cd into BUILD_DIR rather than relying on gnatmake's own -D switch:
	@# confirmed by testing, not assumed -- classic gnatmake's -a
	@# (recompile predefined/runtime units) ignores -D for exactly the
	@# units it recompiles under -a, and writes them to the current
	@# working directory regardless. cd'ing there first is what actually
	@# confines them, since CWD is what genuinely governs placement.
	-cd $(BUILD_DIR) && $(GNATMAKE) -a -g --RTS=$(RTS_DIR) $(SRC_DIRS) \
	  -o bifrost.elf \
	  $(MAIN_FILE) \
	  -cargs $(CPU_SWITCHES) \
	  -largs $(CPU_SWITCHES) -Wl,--gc-sections
	@# setup_pll.adb specifically needs its own, separate invocation:
	@# confirmed by testing, not assumed -- it's never discovered by the
	@# pass above at all (not even attempted), because nothing in the
	@# application's own Ada "with" closure ever references it --
	@# Setup_Pll is called only from assembly/linker-level startup code
	@# (see the installed runtime's start-rom.S), so gnatmake's
	@# with-clause-based dependency walk has no path to it regardless of
	@# -a. Compiling it directly, as its own unit of interest, is what
	@# actually recompiles it against the overridden Board_Parameters.
	cd $(BUILD_DIR) && $(GNATMAKE) -a -c -g --RTS=$(RTS_DIR) \
	  "$(RTS_DIR)/gnat_user/setup_pll.adb" \
	  -cargs $(CPU_SWITCHES)
	@# The link step above is expected to fail -- classic gnatmake
	@# doesn't know gprbuild's runtime.xml-injected -T/startfiles
	@# wiring. Everything this Makefile actually needs (recompiled
	@# .ali/.o for the runtime units) is already written to
	@# $(BUILD_DIR) by the time compile+bind finish, before link ever
	@# runs. The "-" above tolerates that one expected failure; this
	@# check catches anything else (a REAL compile error) instead of
	@# silently ignoring it too.
	@test -f "$(BUILD_DIR)/setup_pll.ali" || { \
	  echo "ERROR: setup_pll.ali was not produced -- the recompile"; \
	  echo "cascade didn't run. Check the gnatmake output above for a"; \
	  echo "real compile error (not the expected 'cannot find crt0.o'"; \
	  echo "link failure)."; \
	  exit 1; \
	}
	@test -f "$(BUILD_DIR)/s-bbbopa.ali" || { \
	  echo "ERROR: s-bbbopa.ali was not produced -- the recompile cascade didn't run."; \
	  exit 1; \
	}
	@echo "Verified: recompile cascade produced the overridden units."
	@echo "Copying recompiled runtime units into $(RTS_DIR)/adalib/ ..."
	@for ali in $(BUILD_DIR)/*.ali; do \
	  base=$$(basename "$$ali" .ali); \
	  case "$$base" in \
	    main|b~main|bifrost*) continue ;; \
	  esac; \
	  cp "$$ali" "$(RTS_DIR)/adalib/"; \
	  if [ -f "$(BUILD_DIR)/$$base.o" ]; then cp "$(BUILD_DIR)/$$base.o" "$(RTS_DIR)/adalib/"; fi; \
	done
	@echo "Done. $(RTS_NAME)'s adalib/ now reflects gnat_user/'s overrides."
	@echo "Ordinary 'gprbuild -P bifrost.gpr' (bash build.sh / buildw.sh)"
	@echo "builds should work normally from here on -- no special flags."
	rm -rf $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
