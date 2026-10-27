-- ============================================================================
-- This file is part of Crosby -- see ../../crosby.gpr's own header.
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

-- Blink LD1 using nothing but a busy-wait counter -- no timer
-- peripheral, no Ravenscar task, no protected object, no delay
-- statement anywhere in this program. "How fast" it blinks is a
-- direct function of this board's actual CPU clock and this loop's
-- compiled instruction count, neither of which this program attempts
-- to pin down precisely -- see crosby.gpr's own header on the
-- runtime's un-overridden Setup_Pll for why that's a deliberately
-- accepted looseness here, not an oversight.
procedure Main is
   Counter : Natural := 0;

   -- Volatile, deliberately: Counter's value, apart from the
   -- threshold comparison below, has no externally visible effect --
   -- without this, a sufficiently aggressive optimizer would be fully
   -- entitled to collapse the counting loop entirely (dead-code
   -- elimination on a loop whose only observable side effect, from
   -- the compiler's point of view, is time spent). Marking it
   -- Volatile forces every increment and comparison to actually
   -- happen. This project's own Default_Switches("Ada") carry no
   -- explicit -O flag (GCC's own default is then -O0, which would not
   -- elide this today regardless) -- Volatile makes that safe against
   -- someone later adding optimization switches without having to
   -- remember why this loop would otherwise break.
   pragma Volatile (Counter);

   State : Boolean := False;

   -- An arbitrary, empirically-adjustable iteration count -- not a
   -- calibrated time duration. Raise or lower it directly to change
   -- the blink rate; there is no clock-rate math behind this number.
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
