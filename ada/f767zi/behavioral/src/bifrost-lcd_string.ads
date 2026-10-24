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

-- Counter -> decimal ASCII formatting for the LCD. Direct port of
-- ../../f722ze-tiny's bifrost-lcd_string.ads -- unchanged. Still a
-- procedure filling a caller-provided fixed buffer, not a function
-- returning an unconstrained String, for the same secondary-stack
-- reason documented there -- light-tasking-stm32f769disco's secondary
-- stack support is not something this port has set up/verified either,
-- so there's no reason to revisit that choice here.
package Bifrost.LCD_String is

   procedure Format
     (Counter : in out Natural;
      Buffer  : out String;
      Length  : out Natural);
   -- Writes the decimal digits of Counter into Buffer (1 .. Length);
   -- Buffer must be at least Bifrost.LCD_Config.LCD_Max_Col characters.
   -- If Counter has reached Bifrost.LCD_Config.LCD_Max_Num, it is reset
   -- to 0 (both Buffer's contents and Counter itself) before formatting.

end Bifrost.LCD_String;
