-- ============================================================================
-- This file is part of samv71-tiny
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

package body Samv71_Tiny.CRC16 is

   function Update (Crc : Unsigned_16; C : Byte) return Unsigned_16 is
      V    : Unsigned_16 := (Crc xor Unsigned_16 (C)) and 16#00FF#;
      Tcrc : Unsigned_16 := 0;
   begin
      for I in 0 .. 7 loop
         if ((Tcrc xor V) and 1) = 1 then
            Tcrc := Shift_Right (Tcrc, 1) xor 16#8408#;
         else
            Tcrc := Shift_Right (Tcrc, 1);
         end if;
         V := Shift_Right (V, 1);
      end loop;
      return Shift_Right (Crc, 8) xor Tcrc;
   end Update;

   function Compute (Data : Byte_Array) return Unsigned_16 is
      Crc : Unsigned_16 := 16#6363#;
   begin
      for B of Data loop
         Crc := Update (Crc, B);
      end loop;
      return Crc;
   end Compute;

end Samv71_Tiny.CRC16;
