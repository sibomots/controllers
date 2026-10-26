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

-- Packed, network-byte-order on-wire mirror of Slate_Of_State. A
-- separate type from Slate_Of_State itself (not just a re-export of
-- it), and deliberately its own package rather than private to
-- Bifrost.Telemetry.Sinks.Udp_Unicast -- a future, simultaneous
-- multicast sink reuses this exact byte layout rather than
-- re-deriving it. One serialization, many destinations.
with Bifrost.Net.Types;

package Bifrost.Telemetry.Wire_Format is

   Wire_Size : constant := 21;
   --  1 (version) + 4 (seq) + 4 (uptime) + 2 + 2 (ADC channels) + 8 (tag)

   -- Result'Length is always Wire_Size -- not expressed as a Post
   -- aspect since no other unit in this codebase uses Pre/Post
   -- contracts and this is a one-line invariant easily verified by
   -- inspection.
   function Serialize
     (Slate : Bifrost.Telemetry.Slate_Of_State) return Bifrost.Net.Types.Byte_Array;

end Bifrost.Telemetry.Wire_Format;
