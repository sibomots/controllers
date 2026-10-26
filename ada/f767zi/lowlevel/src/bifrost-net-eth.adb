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

with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

package body Bifrost.Net.Eth is

   procedure C_Ethernetif_Init
     with Import, Convention => C, External_Name => "bifrost_ethernetif_init";

   procedure C_Ethernetif_Poll
     with Import, Convention => C, External_Name => "bifrost_ethernetif_poll";

   procedure Initialize is
   begin
      C_Ethernetif_Init;
   end Initialize;

   procedure Poll is
   begin
      C_Ethernetif_Poll;
   end Poll;

   -- ------------------------------------------------------------------
   -- Single time base: HAL_GetTick / HAL_Delay, exported to C.
   --
   -- vendor/hal_f7/Src/stm32f7xx_hal.c (which would normally define
   -- these, backed by its own SysTick interrupt) is deliberately NOT
   -- compiled at all -- see bifrost.gpr's own comment on why, and
   -- ../../HARDWARE.md for the still-open ~1/3 clock-tree undershoot
   -- this board's Ada port has already found and worked around
   -- elsewhere (Bifrost.UART's BRR). Letting HAL own a second,
   -- independent SysTick-driven millisecond counter would mean two
   -- competing, potentially-disagreeing time authorities in one
   -- program -- the same single-owner discipline this project already
   -- applies to hardware resources (e.g. Bifrost.LCD_Sink being the
   -- LCD's sole owner) applies here to *time* instead.
   -- ------------------------------------------------------------------

   Boot_Time : constant Time := Clock;

   function HAL_GetTick return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "HAL_GetTick";

   function HAL_GetTick return Interfaces.Unsigned_32 is
      Elapsed : constant Time_Span := Clock - Boot_Time;

      -- Real hardware's HAL_GetTick wraps naturally at 2**32 ms
      -- (~49.7 days) as an unsigned counter. Ada.Real_Time's own
      -- Time_Span "/" operator returns a plain (signed, 32-bit on
      -- this target) Integer and would raise Constraint_Error on
      -- overflow well before that -- computing in Long_Long_Integer
      -- first, then taking an explicit "mod 2**32", reproduces the
      -- real wraparound instead of a latent crash on long uptimes.
      Elapsed_Ms : constant Long_Long_Integer :=
        Long_Long_Integer (To_Duration (Elapsed) * 1000) mod 2 ** 32;
   begin
      return Interfaces.Unsigned_32 (Elapsed_Ms);
   end HAL_GetTick;

   procedure HAL_Delay (Delay_Ms : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "HAL_Delay";

   procedure HAL_Delay (Delay_Ms : Interfaces.Unsigned_32) is
   begin
      -- A plain relative delay, not a busy-wait -- safe here because
      -- every caller of HAL_Delay in this program (PHY register
      -- read/write pacing inside vendor/hal_f7's ETH driver) runs on
      -- an ordinary task's call stack (Main or Telemetry_Sink), never
      -- from interrupt/protected-object context, where a delay
      -- statement would be illegal.
      delay Duration (Delay_Ms) / 1000.0;
   end HAL_Delay;

end Bifrost.Net.Eth;
