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

-- Direct port of rtbus/src/crc.c's Crc32 -- same table-driven algorithm,
-- bit for bit. Pure algorithm, no hardware coupling, mechanical to
-- port. Data'Length replaces the C function's separate len parameter
-- (an array parameter already carries its own bounds in Ada); the C
-- function's "bytes == NULL" special case (treated as zero bytes) has
-- no Ada counterpart to port -- an empty array already behaves that
-- way with no special-casing needed.
with Interfaces;

package Samv71_Tiny.CRC32 is

   function Compute
     (Initial_Crc : Interfaces.Unsigned_32;
      Data        : Byte_Array) return Interfaces.Unsigned_32;

end Samv71_Tiny.CRC32;
