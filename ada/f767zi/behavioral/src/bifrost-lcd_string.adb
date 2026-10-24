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

with Bifrost.LCD_Config;

package body Bifrost.LCD_String is

   procedure Format
     (Counter : in out Natural;
      Buffer  : out String;
      Length  : out Natural)
   is
   begin
      if Counter = 0 then
         Buffer (Buffer'First) := '0';
         Length := 1;
         return;
      end if;

      if Counter >= Bifrost.LCD_Config.LCD_Max_Num then
         Counter := 0;
         Buffer (Buffer'First) := '0';
         Length := 1;
         return;
      end if;

      declare
         -- Least-significant digit first; reversed into Buffer below.
         Reversed : String (1 .. Bifrost.LCD_Config.LCD_Max_Col);
         Count    : Natural := 0;
         Value    : Natural := Counter;
      begin
         while Value > 0 loop
            Count := Count + 1;
            Reversed (Count) :=
              Character'Val (Character'Pos ('0') + Value mod 10);
            Value := Value / 10;
         end loop;

         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) := Reversed (Count - I + 1);
         end loop;
         Length := Count;
      end;
   end Format;

end Bifrost.LCD_String;
