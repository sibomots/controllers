-- ============================================================================
-- This file is part of Bifrost
--
-- Copyright (c) 2025 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

-- Tasking-phase Main -- see ../../SOFTWARE.md. One-time hardware
-- bring-up only; the recurring work (LCD counter display, console I/O)
-- happens in Bifrost.LCD_Sink's and Bifrost.TinyMon's library-level
-- tasks, both already running by the time this procedure's first
-- statement executes (Ravenscar activates library-level tasks during
-- elaboration, before the environment task's body starts -- same
-- ordering ada/samv71-tiny's Main relies on). Main does not touch the
-- LCD at all, deliberately -- see Bifrost.LCD_Sink's task body for why
-- that has to be the one task that owns it, start to finish.
--
-- No hand-written startup to "with" for side effects either (unlike
-- ../../f722ze-tiny's Bifrost.Startup) -- light-tasking-stm32f769disco's
-- own start-rom.S supplies the vector table and Reset Handler
-- equivalent.
with Bifrost.UART;
with Bifrost.TinyMon;

-- Pulled in for its task's elaboration side effect only -- see
-- Bifrost.LCD_Sink's spec comment. Nothing in this procedure calls into
-- it directly, same reason ../../f722ze-tiny's main.adb needed
-- pragma Unreferenced on Bifrost.Startup.
with Bifrost.LCD_Sink;
pragma Unreferenced (Bifrost.LCD_Sink);

procedure Main is
begin
   Bifrost.UART.Initialize;
   Bifrost.TinyMon.Show_Welcome;

   loop
      delay 60.0;
   end loop;
end Main;
