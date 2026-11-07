-- ============================================================================
-- Crosby -- NUCLEO-F767ZI bare-metal Ada minimal example.
--
-- Copyright (c) 2026 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

with Crosby.LED;

-- Blinks LD1 using a busy-wait counter. No timer, no task, no delay
-- statement. The blink rate is a function of CPU clock and loop
-- instruction count, neither pinned down precisely here -- see
-- DESIGN.md.
procedure Main is
   Counter : Natural := 0;

   -- Volatile so the counting loop can't be optimized away: without
   -- this, Counter's only observable effect (from the compiler's
   -- point of view) is time spent, and that's legal to delete.
   pragma Volatile (Counter);

   State : Boolean := False;

   -- Empirically adjustable; not a calibrated time duration.
   Loop_Threshold : constant := 2_000_000;
begin
   Crosby.LED.Initialize;

   loop
      Counter := Counter + 1;

      if Counter >= Loop_Threshold then
         Counter := 0;

         if State then
            Crosby.LED.Off;
         else
            Crosby.LED.On;
         end if;

         State := not State;
      end if;
   end loop;
end Main;
