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

with Interfaces; use Interfaces;

-- Low-level driver for the NHD-0108HZ-FSW-GBW (HD44780-compatible, 8x1
-- character LCD), 4-bit interface, wired to GPIOB per Bifrost.Board.
-- Ported from the C tree's lowlevel/lcd_NHD_0108HZ.c/.h.
--
-- Public surface is tighter than the C header: lcd_set_bit/lcd_clear_bit
-- and lcd_write_byte are exposed there purely as C header convention --
-- nothing outside lcd_NHD_0108HZ.c actually calls them (only
-- lcd_gpio_init, lcd_write_nibble, lcd_write_cmd, lcd_write_data are
-- called from behavioral/lcd_control.c). Those three stay private here.
package Bifrost.LCD is

   procedure Initialize;
   -- Configure the 7 GPIOB lines (DB4..DB7, E, RW, DI) as outputs.
   -- Does not run the HD44780 power-on/4-bit-mode sequence -- that is
   -- behavioral, see Bifrost.LCD_Control.Initialize.

   procedure Write_Nibble (Nibble : Unsigned_8; Is_Data : Boolean);
   -- Sets DB4..DB7 from Nibble's low 4 bits and strobes E. Called
   -- directly (not just via Write_Byte) during the HD44780 4-bit
   -- bring-up sequence, same as the C driver.

   procedure Write_Command (Cmd : Unsigned_8);
   procedure Write_Data (Data : Unsigned_8);

end Bifrost.LCD;
