-- ============================================================================
-- This file is part of Crosby -- see ../../crosby.gpr's own header.
--
-- Copyright (c) 2026 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

-- User LED LD1 (PB0), direct register access via the runtime-bundled
-- Interfaces.STM32 BSP -- no HAL, no abstraction beyond "which pin,
-- which register fields." Confirmed, not assumed: UM1974 Rev 11
-- Section 7.5 ("User LD1: a green user LED is connected to the STM32
-- I/O PB0 ... or PA5") and Table 12's SB120/SB119 solder-bridge entry
-- confirm PB0 is this board's *default* wiring for LD1 (SB120 ON,
-- SB119 OFF); PA5 is the alternate (Arduino D13) wiring, not the
-- default, and is not what this package targets.
--
-- This package is a pure mechanism -- On/Off, nothing else. The
-- *policy* of when to call them (the actual blink timing) belongs to
-- app/src/main.adb, not here, same separation
-- ../../../ada/f767zi/lowlevel/src/bifrost-uart.ad* draws between
-- "move a byte" and "when to move it."
package Crosby.LED is

   procedure Initialize;

   procedure On;
   procedure Off;

end Crosby.LED;
