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

with System;
with Interfaces;
with Bifrost.Net.Types;
with Bifrost.Telemetry.Wire_Format;

package body Bifrost.Telemetry.Sinks.Udp_Unicast is

   procedure C_Udp_Publish (Data : System.Address; Length : Interfaces.Unsigned_16)
     with Import, Convention => C, External_Name => "bifrost_udp_publish";

   procedure Publish (Slate : Bifrost.Telemetry.Slate_Of_State) is
      Bytes : constant Bifrost.Net.Types.Byte_Array :=
        Bifrost.Telemetry.Wire_Format.Serialize (Slate);
   begin
      C_Udp_Publish (Bytes'Address, Bytes'Length);
   end Publish;

end Bifrost.Telemetry.Sinks.Udp_Unicast;
