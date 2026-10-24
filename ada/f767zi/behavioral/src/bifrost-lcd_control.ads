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

-- High-level HD44780 API, built on top of Bifrost.LCD. Direct port of
-- ../../f722ze-tiny's bifrost-lcd_control.ads -- unchanged; built only on
-- Bifrost.LCD's public surface, which itself didn't change shape, only
-- its register-access mechanism (see bifrost-lcd.adb).
package Bifrost.LCD_Control is

   procedure Initialize;
   -- Full power-on / 4-bit-mode bring-up sequence (HD44780 datasheet).

   procedure Clear;
   procedure Home;

   procedure Set_Cursor (Col : Natural);
   -- For the NHD-0108 (8x1), DDRAM column addresses are 0 .. 7.

   procedure Write_Char (C : Character);
   procedure Write_String (S : String);

end Bifrost.LCD_Control;
