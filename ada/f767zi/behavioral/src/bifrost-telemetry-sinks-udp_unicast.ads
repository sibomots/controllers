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

-- The one real sink: serializes the Slate (Bifrost.Telemetry.
-- Wire_Format) and hands the bytes to a small, hand-written C helper
-- (../../lowlevel/src/bifrost_udp_sink.c, NOT vendored) that owns the
-- actual lwIP udp_new/udp_connect/udp_send calls -- lwIP's API is
-- C-struct-heavy (ip_addr_t, pbuf), so a thin C function is a more
-- pragmatic Ada/lwIP boundary than hand-writing deep Ada bindings
-- onto those structs directly, same spirit as
-- ../../lowlevel/src/ethernetif.c already being hand-written C rather
-- than an Ada reimplementation of the HAL/lwIP glue.
package Bifrost.Telemetry.Sinks.Udp_Unicast is

   procedure Publish (Slate : Bifrost.Telemetry.Slate_Of_State);

end Bifrost.Telemetry.Sinks.Udp_Unicast;
