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
-- Direct port of ../../f722ze-tiny/lowlevel/src/bifrost-lcd.ads/.adb --
-- same logic, same public surface; only the register-access mechanism
-- changed (see the body).
package Bifrost.LCD is

   procedure Initialize;
   -- Configure the 7 GPIOB lines (DB4..DB7, E, RW, DI) as outputs.
   -- Does not run the HD44780 power-on/4-bit-mode sequence -- that is
   -- behavioral, see Bifrost.LCD_Control.Initialize.

   procedure Write_Nibble (Nibble : Unsigned_8; Is_Data : Boolean);
   procedure Write_Command (Cmd : Unsigned_8);
   procedure Write_Data (Data : Unsigned_8);

end Bifrost.LCD;
