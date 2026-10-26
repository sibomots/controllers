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
with Ada.Real_Time; use Ada.Real_Time;
with Bifrost.Net.Eth;
with Bifrost.Telemetry.Sinks;

package body Bifrost.Telemetry is

   -- 1Hz -- a reasonable placeholder cadence, same "arbitrary but
   -- documented" spirit as Bifrost.LCD_Sink's own Period comment;
   -- easy to change independently now that this task has something
   -- real to publish each tick.
   Period : constant Time_Span := Seconds (1);

   task body Telemetry_Sink is
      Next_Time : Time;
      Boot_Time : constant Time := Clock;
      Seq       : Interfaces.Unsigned_32 := 0;
   begin
      -- Bifrost.Net.Eth.Initialize is called once from Main, not
      -- here -- same reason Bifrost.UART.Initialize is called from
      -- Main rather than from Bifrost.TinyMon.UART_Sink: this task is
      -- already running (library-level task activation, before
      -- Main's own body starts) before Main gets a chance to bring
      -- the interface up, so Poll below would otherwise race that
      -- bring-up. Harmless today (Bifrost.Net.Eth.Poll on a
      -- not-yet-initialized interface is a well-defined no-op, not a
      -- crash), but worth stating plainly rather than leaving it
      -- implicit.
      Next_Time := Clock;
      loop
         Next_Time := Next_Time + Period;
         delay until Next_Time;

         Bifrost.Net.Eth.Poll;

         declare
            -- Same wraparound-safe conversion Bifrost.Net.Eth's own
            -- HAL_GetTick bridge uses -- a plain Integer division
            -- would raise Constraint_Error on a long enough uptime;
            -- this wraps the way an unsigned millisecond counter
            -- naturally would instead.
            Elapsed_Ms : constant Long_Long_Integer :=
              Long_Long_Integer (To_Duration (Clock - Boot_Time) * 1000)
                mod 2 ** 32;

            Slate : Slate_Of_State;
         begin
            Slate.Sample_Seq := Seq;
            Slate.Uptime_Ms  := Interfaces.Unsigned_32 (Elapsed_Ms);
            -- PLACEHOLDER synthetic ramp, standing in for a real ADC
            -- conversion -- see Slate_Of_State's own field comments.
            Slate.ADC_Channel_0 := Interfaces.Unsigned_16 (Seq mod 1000);

            Bifrost.Telemetry.Sinks.Publish_All (Slate);
         end;

         Seq := Seq + 1;
      end loop;
   end Telemetry_Sink;

end Bifrost.Telemetry;
