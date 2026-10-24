-- ============================================================================
-- This file is part of Bifrost
--
-- Copyright (c) 2025 Jeff Wandling
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

with Interfaces; use Interfaces;
with Interfaces.STM32;      use Interfaces.STM32;
with Interfaces.STM32.RCC;  use Interfaces.STM32.RCC;
with Interfaces.STM32.GPIO; use Interfaces.STM32.GPIO;
with Bifrost.Board;
with Bifrost.Delay_Util;

package body Bifrost.LCD is

   package Board renames Bifrost.Board;

   -- Named signals instead of C's bare "which bit number" parameter --
   -- Set_Bit/Clear_Bit below only ever accept one of these seven, not
   -- an arbitrary integer. Same as ../../f722ze-tiny's Bifrost.LCD.
   type LCD_Signal is (DB4, DB5, DB6, DB7, E, RDWR, DI);

   Pin : constant array (LCD_Signal) of Natural :=
     (DB4  => Board.LCD_DB4,
      DB5  => Board.LCD_DB5,
      DB6  => Board.LCD_DB6,
      DB7  => Board.LCD_DB7,
      E    => Board.LCD_E,
      RDWR => Board.LCD_RDWR,
      DI   => Board.LCD_DI);

   -- GPIOB_Periph.BSRR, not a GPIOB_Periph.ODR read-modify-write: BSRR's
   -- set/reset halves are each a single, hardware-atomic write (bits
   -- written 0 are left alone), avoiding the RMW hazard an ODR approach
   -- would have if anything else ever touched GPIOB concurrently -- not
   -- a correctness fix over f722ze-tiny's version (nothing else touches
   -- GPIOB there either), just the more idiomatic STM32 GPIO access
   -- pattern now that a typed BSRR overlay is available to use directly.
   procedure Set_Bit (Signal : LCD_Signal) is
   begin
      GPIOB_Periph.BSRR :=
        (BS => (As_Array => False, Val => Shift_Left (1, Pin (Signal))),
         BR => (As_Array => False, Val => 0));
   end Set_Bit;

   procedure Clear_Bit (Signal : LCD_Signal) is
   begin
      GPIOB_Periph.BSRR :=
        (BS => (As_Array => False, Val => 0),
         BR => (As_Array => False, Val => Shift_Left (1, Pin (Signal))));
   end Clear_Bit;

   procedure Write_Byte (Value : Unsigned_8; Is_Data : Boolean) is
   begin
      Write_Nibble (Shift_Right (Value, 4) and 16#0F#, Is_Data);
      Write_Nibble (Value and 16#0F#, Is_Data);
   end Write_Byte;

   procedure Initialize is
      -- Interfaces.STM32.UInt32, not plain Interfaces.Unsigned_32 --
      -- GPIOB_Periph.MODER.Val is the former (a distinct derived type,
      -- not implicitly convertible from/to its parent), and Shift_Left
      -- below needs to resolve to UInt32's own inherited version (every
      -- modular type's primitive operations, Shift_Left included, are
      -- inherited by a derived type with the derived type substituted
      -- into the profile) to match it.
      Mode_Bits : Interfaces.STM32.UInt32 := GPIOB_Periph.MODER.Val;

      function Mode_Field (Signal : LCD_Signal) return Interfaces.STM32.UInt32 is
        (Shift_Left (3, Pin (Signal) * 2));
      function Output_Field (Signal : LCD_Signal) return Interfaces.STM32.UInt32 is
        (Shift_Left (1, Pin (Signal) * 2));
   begin
      RCC_Periph.AHB1ENR.GPIOBEN := 1;

      for Signal in LCD_Signal loop
         Mode_Bits :=
           (Mode_Bits and not Mode_Field (Signal)) or Output_Field (Signal);
      end loop;
      GPIOB_Periph.MODER := (As_Array => False, Val => Mode_Bits);

      -- Default levels: E=0, RW=0, DI=0, data lines low.
      for Signal in LCD_Signal loop
         Clear_Bit (Signal);
      end loop;
   end Initialize;

   procedure Write_Nibble (Nibble : Unsigned_8; Is_Data : Boolean) is
   begin
      if Is_Data then
         Set_Bit (DI);
      else
         Clear_Bit (DI);
      end if;

      -- RW = 0 (write only; we do not read the busy flag)
      Clear_Bit (RDWR);

      Clear_Bit (DB4);
      Clear_Bit (DB5);
      Clear_Bit (DB6);
      Clear_Bit (DB7);

      if (Nibble and 2#0001#) /= 0 then
         Set_Bit (DB4);
      end if;
      if (Nibble and 2#0010#) /= 0 then
         Set_Bit (DB5);
      end if;
      if (Nibble and 2#0100#) /= 0 then
         Set_Bit (DB6);
      end if;
      if (Nibble and 2#1000#) /= 0 then
         Set_Bit (DB7);
      end if;

      -- Pulse E to latch the nibble.
      Set_Bit (E);
      Bifrost.Delay_Util.Delay_Us (1);  -- t_pweh >= 230ns for HD44780
      Clear_Bit (E);
      Bifrost.Delay_Util.Delay_Us (50); -- allow command to settle
   end Write_Nibble;

   procedure Write_Command (Cmd : Unsigned_8) is
   begin
      Write_Byte (Cmd, Is_Data => False);
      if Cmd = 16#01# or Cmd = 16#02# then
         -- Clear display / return home need more time.
         Bifrost.Delay_Util.Delay_Ms (2);
      else
         Bifrost.Delay_Util.Delay_Us (50);
      end if;
   end Write_Command;

   procedure Write_Data (Data : Unsigned_8) is
   begin
      Write_Byte (Data, Is_Data => True);
      Bifrost.Delay_Util.Delay_Us (50);
   end Write_Data;

end Bifrost.LCD;
