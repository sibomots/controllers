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

-- GENERATED FILE -- do not hand-edit. Source of truth: ../../net.conf,
-- via ../../gen_net_config.sh. Regenerated on every build.
package Bifrost.Net.Config is

   Our_MAC   : constant Bifrost.Net.Types.MAC_Address :=
     (16#02#, 16#00#, 16#00#, 16#00#, 16#00#, 16#01#);
   Our_IP    : constant Bifrost.Net.Types.IPv4_Address :=
     (192, 168, 10, 100);
   Our_Port  : constant := 5005;

   Dest_IP   : constant Bifrost.Net.Types.IPv4_Address :=
     (192, 168, 10, 8);
   Dest_Port : constant := 6000;

end Bifrost.Net.Config;
