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

-- Phase 6: the real application. Disables the watchdog, brings up
-- USART1 and the LED GPIOs, shows TinyMon's welcome banner and first
-- prompt, then parks -- the real work (console I/O, command dispatch)
-- now happens in Samv71_Tiny.TinyMon's library-level Console task,
-- which is already running by the time this procedure's first
-- statement executes (Ravenscar activates library-level tasks during
-- elaboration, before the environment task's body starts). This
-- supersedes both Phase 3's repeating-send-loop placeholder and Phase
-- 5's hardcoded "cmdb 1" exercise -- real console input over USART1 is
-- the actual mechanism now, not a stand-in for it.
with Samv71_Tiny.WDT_Regs;
with Samv71_Tiny.USART1;
with Samv71_Tiny.Exec_Cmd;
with Samv71_Tiny.TinyMon;

procedure Main is
begin
   Samv71_Tiny.WDT_Regs.WDT_Periph.WDT_MR.WDDIS := 1;
   Samv71_Tiny.USART1.Initialize;
   Samv71_Tiny.Exec_Cmd.Initialize;
   Samv71_Tiny.TinyMon.Show_Welcome;

   loop
      delay 60.0;
   end loop;
end Main;
