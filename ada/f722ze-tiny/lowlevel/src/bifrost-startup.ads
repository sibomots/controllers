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

-- Pure-Ada port of config/src/startup_stm32f722.c -- vector table and
-- Reset_Handler. No C or assembly bootstrap file; see config/stm32f722ze.ld
-- for the linker-provided symbols this depends on (_estack, _sdata,
-- _edata, _sidata, bss_start, bss_end) and ENTRY(Reset_Handler).
package Bifrost.Startup is

   procedure Reset_Handler
     with Export, Convention => C, External_Name => "Reset_Handler";

end Bifrost.Startup;
