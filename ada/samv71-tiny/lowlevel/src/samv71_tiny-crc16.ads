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

-- Direct port of rtbus/src/crc16.c's crc_16 -- same algorithm, same
-- 0x6363 initial value, same 0x8408 polynomial, bit for bit. Pure
-- algorithm, no hardware coupling, mechanical to port.
with Interfaces;

package Samv71_Tiny.CRC16 is

   function Compute (Data : Byte_Array) return Interfaces.Unsigned_16;

end Samv71_Tiny.CRC16;
