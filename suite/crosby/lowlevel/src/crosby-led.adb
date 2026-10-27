-- ============================================================================
-- This file is part of Crosby -- see ../../crosby.gpr's own header.
--
-- Copyright (c) 2026 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

with Interfaces.STM32;      use Interfaces.STM32;
with Interfaces.STM32.RCC;  use Interfaces.STM32.RCC;
with Interfaces.STM32.GPIO; use Interfaces.STM32.GPIO;

package body Crosby.LED is

   procedure Initialize is
   begin
      -- Ungate GPIOB's AHB1 bus clock -- same reasoning as
      -- ../../../ada/f767zi/lowlevel/src/bifrost-uart.adb's identical
      -- GPIODEN write: an unclocked peripheral's registers are
      -- architecturally undefined, not just inert, until this happens.
      RCC_Periph.AHB1ENR.GPIOBEN := 1;

      -- PB0 to General Purpose Output mode: MODER bits[1:0] = "01".
      -- Mask out the existing 2-bit field for pin 0, OR in the new
      -- mode -- the same whole-register read-modify-write idiom
      -- bifrost-uart.adb uses for PD8/PD9's MODER bits, just one pin
      -- instead of two.
      GPIOB_Periph.MODER :=
        (As_Array => False,
         Val      => (GPIOB_Periph.MODER.Val and not 16#0000_0003#)
                      or 16#0000_0001#);
   end Initialize;

   procedure On is
   begin
      -- BSRR, not a read-modify-write on ODR: writing the whole
      -- register in one aggregate assignment (BS=1 sets PB0, BR=0 is
      -- a no-op for every other pin) is the hardware-idiomatic,
      -- race-free way to drive a single output pin -- a read-modify-
      -- write on ODR would work too (nothing else touches GPIOB in
      -- this program), but BSRR is the correct habit to teach even
      -- when it isn't strictly required yet.
      GPIOB_Periph.BSRR :=
        (BS => (As_Array => False, Val => 1),
         BR => (As_Array => False, Val => 0));
   end On;

   procedure Off is
   begin
      GPIOB_Periph.BSRR :=
        (BS => (As_Array => False, Val => 0),
         BR => (As_Array => False, Val => 1));
   end Off;

end Crosby.LED;
