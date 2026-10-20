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

-- LCD counter demo, direct port of the C tree's app/src/main.c, now with
-- TinyMon running alongside it over USART3 -- see Bifrost.UART and
-- Bifrost.TinyMon for the interrupt-driven I/O and console logic. Still
-- procedural (no tasking) -- see ../../SOFTWARE.md for the planned
-- Ravenscar Main/LCD-Sink/UART-Sink task split, not yet done, and
-- Bifrost.UART's spec comment for why this board can't use that
-- approach for interrupt-driven I/O even once that split happens.
-- TinyMon's console poll is non-blocking specifically so it can share
-- this one loop with the LCD update below without ever stalling it.

with Bifrost.LCD_Control;
with Bifrost.LCD_String;
with Bifrost.LCD_Config;
with Bifrost.Delay_Util;
with Bifrost.UART;
with Bifrost.TinyMon;

-- Pulled in for its side effects only: GNAT only compiles/links units
-- reachable via the "with" graph from this Main procedure. Nothing here
-- calls anything in Bifrost.Startup directly -- the hardware calls
-- Reset_Handler via the vector table, not Ada code -- but without this
-- "with", the unit is never compiled at all and the linker has no
-- Reset_Handler symbol to satisfy "-Wl,-e,Reset_Handler".
with Bifrost.Startup;
pragma Unreferenced (Bifrost.Startup);

procedure Main is
   Counter : Natural := 0;
begin
   Bifrost.LCD_Control.Initialize;
   Bifrost.UART.Initialize;
   Bifrost.TinyMon.Show_Welcome;

   Bifrost.LCD_Control.Set_Cursor (0);
   Bifrost.LCD_Control.Write_String ("BIFROST");
   Bifrost.Delay_Util.Delay_Ms (500);
   Bifrost.LCD_Control.Clear;

   loop
      Bifrost.Delay_Util.Delay_Ms (5);
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

      declare
         C   : Character;
         Got : Boolean;
      begin
         Bifrost.UART.Try_Get (C, Got);
         if Got then
            Bifrost.TinyMon.Parse (C);
         end if;
      end;
   end loop;
end Main;
