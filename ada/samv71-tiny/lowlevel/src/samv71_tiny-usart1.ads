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

-- USART1 driver (EDBG_COM: PA21/RXD1, PB4/TXD1), interrupt-driven both
-- directions -- the Ada counterpart to c/samv71-tiny's usart1.c, but
-- built on real Ravenscar tasking primitives instead of a hand-rolled
-- ISR/vector-table entry: a protected object (declared in the body)
-- owns the TX/RX ring buffers and the USART1 interrupt handler
-- (Ada.Interrupts, pragma Attach_Handler), with blocking Put/Get
-- realized as protected entries rather than usart1.c's busy-retry
-- io_write/io_read contract.
--
-- Baud rate: 115200 at the runtime's native Master Clock (150MHz,
-- Setup_Pll's PLLA/2 divider, left unmodified -- see the plan's "Clock
-- and baud" note). This is a freshly computed divisor, not usart1.c's
-- CD=162/FP=6 -- those were computed for 300MHz and only produced a
-- correct baud by accident of chip_init.c's unrelated MCK/3 choice
-- (300/3 = 100MHz, 115200/3 = 38400 -- the real reason PuTTY had to be
-- set to 38400 on the C side).
package Samv71_Tiny.USART1 is

   procedure Initialize;

   procedure Put (Item : Character);

   procedure Get (Item : out Character);

end Samv71_Tiny.USART1;
