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

-- Busy-wait NOP-loop delays, recalibrated from ../../f722ze-tiny's
-- version for this board's clock -- see the body for the derivation.
-- Kept as a busy-wait, not Ada.Real_Time/delay, even though this port
-- has real tasking: the HD44780's shortest timing requirement (t_pweh,
-- the E-strobe pulse width, >=230ns) is well under what a scheduled
-- `delay` can resolve against a SysTick-driven clock -- this is a
-- hardware protocol timing primitive, not a scheduling concern, same as
-- it was on f722ze-tiny.
package Bifrost.Delay_Util is

   procedure Delay_Cycles (Count : Natural);
   procedure Delay_Us (Us : Natural);
   procedure Delay_Ms (Ms : Natural);

end Bifrost.Delay_Util;
