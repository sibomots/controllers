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

-- Busy-wait NOP-loop delays. Ported from the C tree's lowlevel/delay.c and
-- behavioral/sleep.c -- those were two near-duplicate files (sleep.c was
-- just a one-line wrapper calling delay_ms), collapsed here into one
-- package since the extra layer added nothing.
package Bifrost.Delay_Util is

   procedure Delay_Cycles (Count : Natural);
   procedure Delay_Us (Us : Natural);
   procedure Delay_Ms (Ms : Natural);

end Bifrost.Delay_Util;
