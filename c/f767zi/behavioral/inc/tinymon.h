// ============================================================================
// This file is part of Bifrost
//
// Copyright (c) 2025 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================
#ifndef __BIFROST_TINYMON_H__
#define __BIFROST_TINYMON_H__

#include <stdint.h>

// TinyMon, brought over from the Ada port of this board (which itself
// brought it over from ada/samv71-tiny): a line editor and command
// dispatcher running over the console UART (usart3). Minimal command
// set for now ("help", "count") -- there's an opportunity to hook up
// more meaningful commands later, same stand-in spirit the SAMV71
// port's original cmda/cmdb/cmdc had.
//
// No console task or interrupt-driven dispatch of its own -- main's own
// loop calls tinymon_poll once per iteration, alongside its existing
// LCD counter update. tinymon_parse (called internally by tinymon_poll)
// is plain, non-reentrant code; it's safe here only because main's loop
// is the single caller.
//
// Owns usart3 (lowlevel) entirely -- init, polling, everything -- so
// main.c only ever needs this one header, matching this codebase's own
// app -> behavioral -> lowlevel layering (main.c has never included a
// lowlevel header directly, and reaching into usart3.h from app/ hit a
// real gap in the CMake include-path wiring: bifrost_app only links
// against bifrost_behavioral, not bifrost_lowlevel directly, so
// lowlevel/inc was never actually visible there).

// Brings up usart3 and shows the welcome banner + first prompt. Call
// once from main, in place of what would otherwise be a separate
// usart3_init() call.
void tinymon_init(void);

// Call once per main-loop iteration. Non-blocking -- checks for a
// waiting byte and, if there is one, feeds it to the line editor/
// dispatcher. Never stalls the caller's loop.
void tinymon_poll(void);

// main's loop calls this each iteration to keep the "count" command's
// answer current.
void tinymon_set_counter(uint32_t value);

#endif
