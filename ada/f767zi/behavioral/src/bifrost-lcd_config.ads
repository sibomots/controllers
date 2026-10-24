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

-- Direct port of ../../f722ze-tiny's bifrost-lcd_config.ads -- unchanged;
-- this package is pure constants, not board-specific.
package Bifrost.LCD_Config is

   LCD_Max_Col : constant := 8;
   LCD_Max_Num : constant := 99_999_999;

end Bifrost.LCD_Config;
