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

-- Board-specific constants for the SAMV71 Xplained Ultra, mirroring
-- c/samv71-tiny/main/lowlevel/include/board.h's pin mnemonics and
-- semantic aliases.
--
-- Unlike board.h, there is no generic "port index" encoding here: each
-- SAMV71 PIO port already has its own distinct, already-bound Ada object
-- (Interfaces.SAM.PIO.PIOA_Periph .. PIOE_Periph) -- a pin's host port is
-- selected by referencing the right object directly in driver code, not
-- computed from an encoded value the way board.h's GPIO(port,pin) macro
-- had to.
--
-- Peripheral *function* selection (which of PIOx's A/B/C/D muxes a given
-- pin needs) is not declared here -- that type and the procedure that
-- uses it belong with the PIO-configuring driver code once it is
-- written, not speculatively here.
package Samv71_Tiny.Board is
   pragma Pure;

   --  PA23 -- LED0
   PA23 : constant := 23;
   LED0 : constant := PA23;

   --  PC9 -- LED1
   PC9  : constant := 9;
   LED1 : constant := PC9;

   --  PA21 -- USART1 RXD1 (peripheral function A)
   PA21 : constant := 21;

   --  PB4 -- USART1 TXD1 (peripheral function D; shared with JTAG TDI,
   --  needs Interfaces.SAM.MATRIX.CCFG_SYSIO.SYSIO4 released)
   PB4  : constant := 4;

   --  Peripheral IDs (PMC clock-enable bit / NVIC interrupt line number).
   --  PIOA_ID etc. already exist in System.SAMV71; USART1 and
   --  TC0_CHANNEL0 don't, so they are added here instead.
   USART1_Peripheral_ID       : constant := 14;
   TC0_Channel0_Peripheral_ID : constant := 23;

end Samv71_Tiny.Board;
