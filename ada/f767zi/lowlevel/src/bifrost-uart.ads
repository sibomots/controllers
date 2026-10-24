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

-- USART3 driver (PD8 TX / PD9 RX, the ST-LINK Virtual COM Port), the
-- tasking-phase counterpart to ../../f722ze-tiny/lowlevel/src/bifrost-
-- uart.ads. That version had to hand-extend the vector table and
-- lock-free-ring-buffer its way to interrupt-driven I/O because no
-- Ravenscar runtime exists for F722ZE. This board's light-tasking-
-- stm32f769disco runtime has real Ravenscar tasking, so this driver is
-- built the way ada/samv71-tiny's Samv71_Tiny.USART1 already is: a
-- protected object (declared in the body) owns the TX/RX ring buffers
-- and the real USART3 interrupt handler (Ada.Interrupts,
-- pragma Attach_Handler), with blocking Put/Get realized as protected
-- entries instead of a busy-retry/non-blocking Try_Get contract.
package Bifrost.UART is

   procedure Initialize;

   procedure Put (Item : Character);
   procedure Put_Line (Item : String);

   -- Blocking -- unlike f722ze-tiny's Try_Get, there is a real task
   -- (Bifrost.TinyMon's UART_Sink) to block on this entry rather than a
   -- single procedural main loop that cannot afford to stall.
   procedure Get (Item : out Character);

end Bifrost.UART;
