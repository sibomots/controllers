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

-- Counter -> decimal ASCII formatting for the LCD. Mirrors the C tree's
-- behavioral/lcd_string.c/.h, minus the boilerplate Ada doesn't need:
-- no manual null-termination, no null-pointer defensive branch (not
-- reachable here -- Counter is a plain Natural, not a pointer).
--
-- Deliberately a procedure filling a caller-provided fixed buffer,
-- NOT a function returning an unconstrained String: a prior version
-- did that and crashed on real hardware (Storage_Error via
-- System.Secondary_Stack.SS_Allocate, caught by
-- __gnat_last_chance_handler) -- this hand-rolled startup doesn't set
-- up whatever the light-cortex-m7f runtime expects for the secondary
-- stack that unconstrained-type returns rely on. A fixed out buffer
-- + Length sidesteps the secondary stack entirely, same as the C
-- original's own fixed-buffer approach.
package Bifrost.LCD_String is

   procedure Format
     (Counter : in out Natural;
      Buffer  : out String;
      Length  : out Natural);
   -- Writes the decimal digits of Counter into Buffer (1 .. Length);
   -- Buffer must be at least Bifrost.LCD_Config.LCD_Max_Col characters.
   -- If Counter has reached Bifrost.LCD_Config.LCD_Max_Num, it is reset
   -- to 0 (both Buffer's contents and Counter itself) before
   -- formatting -- same rollover behavior as the C version's pointer
   -- write-back.
   --
   -- One deliberate deviation from the literal C behavior: the C
   -- version's rollover case produces an *empty* string (the digit
   -- loop never runs on a freshly-zeroed value), inconsistent with
   -- its own explicit Counter=0 case elsewhere in the same function,
   -- which returns "0". This version returns "0" for both, since
   -- that's clearly the intended behavior.

end Bifrost.LCD_String;
