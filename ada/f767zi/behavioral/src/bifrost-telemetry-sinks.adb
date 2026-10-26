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

with Bifrost.Telemetry.Sinks.Udp_Unicast;
-- Adding a sink: write a new Bifrost.Telemetry.Sinks.<Name> package
-- exposing the identical "procedure Publish (Slate : Slate_Of_State)"
-- profile, add one "with" line here, and one call line below.
--   with Bifrost.Telemetry.Sinks.Udp_Multicast;   -- future
--   with Bifrost.Telemetry.Sinks.Mil1553;         -- future, not now
--   with Bifrost.Telemetry.Sinks.Arinc429;        -- future, not now

package body Bifrost.Telemetry.Sinks is

   procedure Publish_All (Slate : Bifrost.Telemetry.Slate_Of_State) is
   begin
      Bifrost.Telemetry.Sinks.Udp_Unicast.Publish (Slate);
      -- Bifrost.Telemetry.Sinks.Udp_Multicast.Publish (Slate);  -- future
   end Publish_All;

end Bifrost.Telemetry.Sinks;
