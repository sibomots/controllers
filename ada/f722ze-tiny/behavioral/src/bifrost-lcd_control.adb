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
with Bifrost.LCD;
with Bifrost.Delay_Util;

package body Bifrost.LCD_Control is

   procedure Clear is
   begin
      Bifrost.LCD.Write_Command (16#01#); -- Clear display
   end Clear;

   procedure Home is
   begin
      Bifrost.LCD.Write_Command (16#02#); -- Return home
   end Home;

   procedure Set_Cursor (Col : Natural) is
   begin
      -- Set DDRAM address, clamped to the 8 valid columns.
      Bifrost.LCD.Write_Command (16#80# or Unsigned_8 (Col mod 8));
   end Set_Cursor;

   procedure Write_Char (C : Character) is
   begin
      Bifrost.LCD.Write_Data (Unsigned_8 (Character'Pos (C)));
   end Write_Char;

   procedure Write_String (S : String) is
   begin
      for C of S loop
         Write_Char (C);
      end loop;
   end Write_String;

   -- Initialization sequence for a 4-bit HD44780-compatible LCD,
   -- same order/constants as the C tree's lcd_init.
   procedure Initialize is
   begin
      Bifrost.LCD.Initialize;

      -- Initial power-on delay: >15ms
      Bifrost.Delay_Util.Delay_Ms (20);

      -- 4-bit init sequence (HD44780 datasheet). We are only using
      -- DB4..DB7, so send 0x3 (8-bit mode) as a nibble three times,
      -- then 0x2 to switch to 4-bit mode.
      Bifrost.LCD.Write_Nibble (16#03#, Is_Data => False);
      Bifrost.Delay_Util.Delay_Ms (5);

      Bifrost.LCD.Write_Nibble (16#03#, Is_Data => False);
      Bifrost.Delay_Util.Delay_Us (150);

      Bifrost.LCD.Write_Nibble (16#03#, Is_Data => False);
      Bifrost.Delay_Util.Delay_Us (150);

      Bifrost.LCD.Write_Nibble (16#02#, Is_Data => False); -- Set 4-bit mode
      Bifrost.Delay_Util.Delay_Us (150);

      -- Now full commands can be sent in 4-bit mode.

      -- Function set: 4-bit, 1-line, 5x8 font.
      -- 0b0010NFxx: N=0 (1 line), F=0 (5x8) -> 0x20
      Bifrost.LCD.Write_Command (16#20#);

      -- Display OFF
      Bifrost.LCD.Write_Command (16#08#);

      -- Display clear
      Clear;

      -- Entry mode set: increment, no shift (0x06)
      Bifrost.LCD.Write_Command (16#06#);

      -- Display ON, cursor off, blink off (0x0C)
      Bifrost.LCD.Write_Command (16#0C#);
   end Initialize;

end Bifrost.LCD_Control;
