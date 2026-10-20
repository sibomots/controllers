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

-- Mirrors the C tree's behavioral/lcd_config.h. Spec-only -- no body
-- needed for a package that declares nothing but constants.
package Bifrost.LCD_Config is

   LCD_Max_Col : constant := 8;
   LCD_Max_Num : constant := 99_999_999;

end Bifrost.LCD_Config;
