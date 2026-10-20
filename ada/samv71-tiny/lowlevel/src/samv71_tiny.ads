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

with Interfaces;

-- Root namespace for the samv71-tiny application -- same role
-- bifrost.ads plays for the bifrost port, except not quite empty: the
-- raw-byte buffer type the rtbus wire protocol (and the CRC routines it
-- uses) share lives here rather than in Samv71_Tiny.RTBus itself, so
-- that a byte-array type doesn't have to be re-declared (or made to
-- depend on RTBus) wherever it's needed.
--
-- Pure (not just Preelaborate): Samv71_Tiny.Board is Pure, and a Pure
-- unit's parent must be at least as strict (Preelaborate wouldn't be
-- enough) -- discovered via a real compile error, not anticipated here.
--
-- No_Elaboration_Code_All also propagates up the parent chain the same
-- way: the *_Regs children declare it, and GNAT rejected them with
-- "unit Samv71_Tiny does not have No_Elaboration_Code_All" until it was
-- added here too -- another real compile error, not anticipated.
package Samv71_Tiny is
   pragma Pure;
   pragma No_Elaboration_Code_All;

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;
end Samv71_Tiny;
