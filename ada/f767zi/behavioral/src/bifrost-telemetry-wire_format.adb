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

package body Bifrost.Telemetry.Wire_Format is

   -- Genuine network-byte-order (big-endian) wire format, packed by
   -- hand, byte by byte -- a GNAT Scalar_Storage_Order record was
   -- tried first (the more idiomatic GNAT mechanism for this, and
   -- what this feature's own design notes originally called for) but
   -- hit a real, confirmed compiler restriction: GNAT requires every
   -- component's own type to carry a matching Scalar_Storage_Order,
   -- and Bifrost.Net.Types.Byte_Array (used for User_Tag) doesn't
   -- declare one of its own, which GNAT rejects even though a
   -- byte array has no multi-byte endianness to disagree about in
   -- the first place. Hand-splitting avoids that restriction
   -- entirely and is the same technique ada/samv71-tiny's RTBus
   -- already uses (there for little-endian; here for big-endian) --
   -- not a new invention, just the other byte order.
   function Serialize
     (Slate : Bifrost.Telemetry.Slate_Of_State) return Bifrost.Net.Types.Byte_Array
   is
      use Bifrost.Net.Types;
      Bytes : Byte_Array (1 .. Wire_Size);
      I     : Positive := 1;

      procedure Put_U8 (Value : Unsigned_8) is
      begin
         Bytes (I) := Value;
         I := I + 1;
      end Put_U8;

      procedure Put_U16 (Value : Unsigned_16) is
      begin
         Put_U8 (Unsigned_8 (Shift_Right (Value, 8) and 16#FF#));
         Put_U8 (Unsigned_8 (Value and 16#FF#));
      end Put_U16;

      procedure Put_U32 (Value : Unsigned_32) is
      begin
         Put_U8 (Unsigned_8 (Shift_Right (Value, 24) and 16#FF#));
         Put_U8 (Unsigned_8 (Shift_Right (Value, 16) and 16#FF#));
         Put_U8 (Unsigned_8 (Shift_Right (Value, 8) and 16#FF#));
         Put_U8 (Unsigned_8 (Value and 16#FF#));
      end Put_U32;
   begin
      Put_U8  (Slate.Slate_Version);
      Put_U32 (Slate.Sample_Seq);
      Put_U32 (Slate.Uptime_Ms);
      Put_U16 (Slate.ADC_Channel_0);
      Put_U16 (Slate.ADC_Channel_1);

      for C of Slate.User_Tag loop
         Put_U8 (Unsigned_8 (Character'Pos (C)));
      end loop;

      return Bytes;
   end Serialize;

end Bifrost.Telemetry.Wire_Format;
