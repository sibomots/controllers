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

-- The "LCD Sink" task named in ../../SOFTWARE.md's planned Main/LCD_Sink/
-- UART_Sink architecture -- the counterpart to Bifrost.TinyMon's
-- UART_Sink task. ../../f722ze-tiny had no task to put this on at all:
-- its Main procedure's own loop body did the counter-format-and-display
-- work directly, once per iteration, at whatever cadence
-- Bifrost.Delay_Util.Delay_Ms happened to block for -- a cadence that
-- was really there to bound how long console polling could be stalled,
-- not chosen for display legibility. With UART handling moved to its
-- own event-driven task (Bifrost.TinyMon.UART_Sink), that coupling is
-- gone, so this task picks its own period independently -- see the body.
--
-- No public operations: this package exists only to own its task.
-- Bifrost.LCD_Control.Initialize and the one-time "BIFROST" splash are
-- still done directly by Main, same as ../../f722ze-tiny -- only the
-- ongoing per-tick counter display moves here, matching the "Main does
-- one-time bring-up; tasks do the recurring work" split
-- ada/samv71-tiny's Main already established.
package Bifrost.LCD_Sink is
   pragma Elaborate_Body;
   -- An empty spec would otherwise not "allow" a body at all (GNAT only
   -- requires/permits a body for a spec that declares something needing
   -- one) -- this package's only content is the task declared directly
   -- in its body, so Elaborate_Body is what makes that legal.
end Bifrost.LCD_Sink;
