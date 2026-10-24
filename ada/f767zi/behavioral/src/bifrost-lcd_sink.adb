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

with System;
with Ada.Real_Time; use Ada.Real_Time;
with Bifrost.LCD_Control;
with Bifrost.LCD_String;
with Bifrost.LCD_Config;
with Bifrost.TinyMon;

package body Bifrost.LCD_Sink is

   -- Chosen for display legibility (10Hz is already far faster than a
   -- human reads a counter), not derived from any hardware timing
   -- requirement -- unlike ../../f722ze-tiny's Delay_Ms(5), which was a
   -- stand-in cadence for the whole polled super-loop, not a
   -- deliberate display-rate choice. Free to change without touching
   -- anything else now that this task's period is fully decoupled from
   -- console I/O.
   Period : constant Time_Span := Milliseconds (100);

   task LCD_Sink is
      pragma Priority (System.Priority'First);
      -- Lowest regular task priority -- see Bifrost.TinyMon.UART_Sink's
      -- comment for why console responsiveness outranks this task.
   end LCD_Sink;

   task body LCD_Sink is
      Next_Time : Time;
      Counter   : Natural := 0;
   begin
      -- Bifrost.LCD_Control.Initialize and the one-time "BIFROST"
      -- splash both live here, not in Main, and deliberately so:
      -- Bifrost.LCD/.LCD_Control have no protected object guarding
      -- their GPIO bit-banging (same as ../../f722ze-tiny -- nothing
      -- about adding tasking elsewhere in this port changed that), so
      -- the LCD can only ever be safely touched by exactly one task for
      -- the program's whole lifetime. Doing the splash from Main's own
      -- task instead, concurrently with this task already running (a
      -- library-level task is activated during elaboration, before the
      -- environment task's body even starts -- Main would be racing a
      -- task that's already live, not one it starts itself) would
      -- interleave two tasks' nibble-at-a-time writes into the same
      -- HD44780 bitstream. Giving this task sole ownership of
      -- Bifrost.LCD_Control end to end -- bring-up, splash, and the
      -- recurring counter display -- is what keeps that single-owner
      -- invariant true, the same way Bifrost.UART's protected object
      -- keeps USART3 safe for its own two accessors instead.
      Bifrost.LCD_Control.Initialize;
      Bifrost.LCD_Control.Set_Cursor (0);
      Bifrost.LCD_Control.Write_String ("BIFROST");
      delay 0.5;
      Bifrost.LCD_Control.Clear;

      Next_Time := Clock;
      loop
         Next_Time := Next_Time + Period;
         delay until Next_Time;

         declare
            Display : String (1 .. Bifrost.LCD_Config.LCD_Max_Col);
            Length  : Natural;
         begin
            Bifrost.LCD_String.Format (Counter, Display, Length);
            Bifrost.LCD_Control.Set_Cursor (0);
            Bifrost.LCD_Control.Write_String (Display (1 .. Length));
         end;

         Counter := Counter + 1;
         Bifrost.TinyMon.Set_Counter (Counter);
      end loop;
   end LCD_Sink;

end Bifrost.LCD_Sink;
