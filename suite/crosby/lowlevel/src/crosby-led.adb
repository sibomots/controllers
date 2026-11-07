-- ============================================================================
-- Crosby -- NUCLEO-F767ZI bare-metal Ada minimal example.
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
      -- Ungate GPIOB's clock before touching its registers.
      RCC_Periph.AHB1ENR.GPIOBEN := 1;

      -- PB0 to General Purpose Output mode: MODER bits[1:0] = "01".
      GPIOB_Periph.MODER :=
        (As_Array => False,
         Val      => (GPIOB_Periph.MODER.Val and not 16#0000_0003#)
                      or 16#0000_0001#);
   end Initialize;

   procedure On is
   begin
      -- BSRR sets/resets a pin atomically, without a read-modify-
      -- write on ODR.
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
