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

-- Minimal, shared Ada-side network types. Deliberately not a packet-
-- building layer (ARP/IPv4/UDP header records) -- lwIP (vendor/lwip)
-- does that work now; this package exists only to give
-- Bifrost.Net.Config a typed way to express a MAC/IPv4 address, and
-- to give Bifrost.Telemetry.Wire_Format a raw byte-array result type
-- for the serialized Slate_Of_State payload handed across the Ada/C
-- boundary to bifrost_udp_publish.
with Interfaces;

package Bifrost.Net.Types is

   subtype Octet is Interfaces.Unsigned_8;

   type MAC_Address  is array (0 .. 5) of Octet;
   type IPv4_Address is array (0 .. 3) of Octet;
   type Byte_Array   is array (Natural range <>) of Octet;

end Bifrost.Net.Types;
