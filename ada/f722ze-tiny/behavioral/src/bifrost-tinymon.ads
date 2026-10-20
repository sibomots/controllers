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

-- TinyMon, brought over from ada/samv71-tiny/c/samv71-tiny: a line
-- editor and command dispatcher running over the console UART
-- (Bifrost.UART, USART3). Minimal command set for now ("help", "count")
-- -- there's an opportunity to hook up more meaningful commands later,
-- same stand-in spirit ada/samv71-tiny's original cmda/cmdb/cmdc had.
--
-- Structural difference from ada/samv71-tiny's TinyMon: no library-level
-- Console task here -- this board has no Ravenscar tasking runtime at
-- all (see Bifrost.UART's spec comment). app/src/main.adb's own loop
-- calls Bifrost.UART.Try_Get once per iteration and feeds any byte
-- straight to Parse below, alongside its existing LCD counter update --
-- a direct structural consequence of there being no task to block a
-- Get on, not an oversight relative to the SAMV71 port.
package Bifrost.TinyMon is

   procedure Show_Welcome;

   -- Call once per main-loop iteration with the byte Try_Get produced,
   -- if any.
   procedure Parse (C : Character);

   -- main.adb calls this each iteration to keep the "count" command's
   -- answer current. This is a mirror of main.adb's own Counter, not
   -- the literal variable -- see the body for the one minor, accepted
   -- consequence of that (the rollover-to-zero case).
   procedure Set_Counter (Value : Natural);

end Bifrost.TinyMon;
