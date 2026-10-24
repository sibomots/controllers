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
      -- f722ze-tiny's "Us*5" constant was calibrated for HSI 16MHz, no
      -- PLL (HCLK=16MHz). This board runs HCLK=SYSCLK=200MHz (AHB_PRE=
      -- DIV1 -- see System.BB.Parameters) once ../runtime-overrides/ is
      -- installed -- 12.5x the old clock. The loop body's CPU-cycle
      -- count per iteration doesn't change with clock frequency, only
      -- how much wall-clock time each cycle takes -- so hitting the same
      -- wall-clock delay at 12.5x the frequency takes 12.5x the
      -- iterations: 5 * 12.5 = 62.5, rounded up (not down -- HD44780's
      -- timing requirements are documented minimums; erring long is
      -- safe, erring short is not) to 63.
      --
      -- This is a first-order estimate, not a measured one -- no
      -- F767ZI was in hand to verify against at the time of this port
      -- (see ../../../HARDWARE.md). Re-verify with a scope once real
      -- hardware is available, same category of risk already flagged
      -- for SysTick recalibration in ../../../KNOWN_ISSUES.md -- a
      -- software NOP loop's actual cycles-per-iteration can shift with
      -- cache/prefetch behavior at a different clock, not just scale
      -- linearly in the ideal case assumed here.
      Delay_Cycles (Us * 63);
   end Delay_Us;

   procedure Delay_Ms (Ms : Natural) is
   begin
      -- Same 12.5x scaling as Delay_Us, same rounding-up rationale:
      -- 7656 * 12.5 = 95_700.
      Delay_Cycles (Ms * 95_700);
   end Delay_Ms;

end Bifrost.Delay_Util;
