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

with System.Machine_Code; use System.Machine_Code;

package body Bifrost.Delay_Util is

   procedure Delay_Cycles (Count : Natural) is
      N : Natural := Count;
   begin
      while N > 0 loop
         N := N - 1;
         Asm ("nop", Volatile => True);
      end loop;
   end Delay_Cycles;

   procedure Delay_Us (Us : Natural) is
   begin
      -- Same scaling constant as the C original (us + (us << 2) = us * 5),
      -- calibrated against the default reset clock (HSI 16 MHz, no PLL --
      -- SystemInit is a no-op in both the C and Ada startup code).
      Delay_Cycles (Us * 5);
   end Delay_Us;

   procedure Delay_Ms (Ms : Natural) is
   begin
      -- Same scaling constant as the C original's shift sum
      -- ((ms<<12)+(ms<<11)+(ms<<10)+(ms<<8)+(ms<<7)+(ms<<6)+(ms<<5)+(ms<<3)
      -- = ms * 7656), same clock assumption as Delay_Us above.
      Delay_Cycles (Ms * 7656);
   end Delay_Ms;

end Bifrost.Delay_Util;
