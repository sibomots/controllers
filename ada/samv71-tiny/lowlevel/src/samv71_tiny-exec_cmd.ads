-- ============================================================================
-- This file is part of samv71-tiny
--
-- Copyright (c) 2025 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

-- Direct port of rtbus/include/exec_cmd.h + rtbus/src/exec_cmd.c -- the
-- LED toggle behavior on cmdb (on)/cmdc (off).
--
-- exec_cmda/b/c's C signatures take a "const uint32_t *const args"
-- pointer (defensively NULL-checked even though populate_exec_arr never
-- actually passes NULL); since nothing here ever reads more than the
-- first argument, Exec_Cmdb/Exec_Cmdc below just take that value
-- directly as an Unsigned_32, and Exec_Cmda takes nothing -- no pointer
-- indirection to replicate once the value itself is all that's used.
-- Populate_Exec_Arr correspondingly stores the (small, bounded) argument
-- values themselves rather than a pointer into the packet buffer the
-- C version stored (which was only ever safe because render_pins() runs
-- shortly after, same cycle, while that static/reused buffer is still
-- intact -- storing values instead removes that lifetime assumption
-- entirely rather than replicating it).
with Interfaces;        use Interfaces;
with Samv71_Tiny.RTBus;

package Samv71_Tiny.Exec_Cmd is

   -- LED0 (PA23)/LED1 (PC9) as plain GPIO outputs, initially off --
   -- the piece of c/samv71-tiny's board_init.c's system_init() that
   -- hadn't been ported yet (Phase 3 only carried over the watchdog
   -- disable and USART1 bring-up); needed here because Exec_Cmdb/
   -- Exec_Cmdc don't do anything observable without it.
   procedure Initialize;

   procedure Render_Pins;

   procedure Populate_Exec_Arr
     (Cmd_Id : Unsigned_16;
      Args   : Samv71_Tiny.RTBus.Arg_Array);

   procedure Exec_Cmda;
   procedure Exec_Cmdb (Led_Id : Unsigned_32);
   procedure Exec_Cmdc (Led_Id : Unsigned_32);

end Samv71_Tiny.Exec_Cmd;
