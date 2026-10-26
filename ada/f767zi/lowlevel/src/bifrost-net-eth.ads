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

-- Ada face of the Ethernet/lwIP bring-up. The actual MAC/DMA/PHY
-- driver (vendor/hal_f7, vendor/lan8742) and the lwIP network
-- interface glue (../src/ethernetif.c, hand-written, NOT vendored)
-- are C; this package is a thin wrapper calling into that C layer,
-- plus the single-time-base bridge (HAL_GetTick/HAL_Delay, exported
-- from the body) that keeps HAL/lwIP riding on this project's one
-- real time authority, Ada.Real_Time, instead of a second, competing
-- SysTick -- see ../../../HARDWARE.md and the plan's own "Decision 2"
-- for why.
package Bifrost.Net.Eth is

   -- Brings up the Ethernet MAC/DMA + LAN8742A PHY and the lwIP
   -- network interface. Call once from Main, after
   -- Bifrost.UART.Initialize (console first, for debug visibility if
   -- bring-up has anything to say) and before any task starts relying
   -- on the interface being up -- see ethernetif.c's own comment on
   -- the one real ordering gap this leaves (Telemetry_Sink is already
   -- running, library-level-task-activation-before-Main-body-runs,
   -- same as every other task in this port; harmless today since
   -- nothing calls Poll before Initialize has actually run in
   -- practice, but flagged exactly like Bifrost.LCD_Sink's own
   -- ordering comment flags its analogous case).
   procedure Initialize;

   -- Call once per Telemetry_Sink tick: drains any received Ethernet
   -- frames into lwIP and services lwIP's internal timeouts
   -- (sys_check_timeouts). Replaces the reference example's tight
   -- `while(1) { ethernetif_input(); sys_check_timeouts(); }` with
   -- this project's own Ravenscar periodic-task cadence instead.
   procedure Poll;

end Bifrost.Net.Eth;
