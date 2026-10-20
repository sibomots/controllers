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

-- USART3 driver, interrupt-driven in both directions. USART3 on PD8
-- (TX) / PD9 (RX) is the ST-LINK Virtual COM Port on this board, enabled
-- by default solder-bridge configuration (SB5/SB6 ON, per UM1974) -- no
-- hardware rework needed.
--
-- Unlike ada/samv71-tiny's USART1 driver, this cannot use a protected
-- object + Ada.Interrupts.Attach_Handler -- there is no Ravenscar
-- tasking runtime for this board (confirmed: only light-cortex-m7f
-- exists, a non-tasking profile; Ada.Interrupts/System.Interrupts come
-- from GNARL, which that runtime doesn't include). Interrupt-driven I/O
-- here is built the older way instead: Interrupt_Handler is a plain Ada
-- procedure whose address Bifrost.Startup places directly into a
-- hand-extended vector table, and the TX/RX ring buffers in the body
-- are a lock-free single-producer/single-consumer design (Volatile
-- shared state, no locking) rather than protected-object-guarded state.
package Bifrost.UART is

   procedure Initialize;
   procedure Put (Item : Character);
   procedure Put_Line (Item : String);

   -- Non-blocking: Got is False if no byte is waiting. Deliberately not
   -- a blocking Get -- main.adb's loop must keep updating the LCD every
   -- iteration, so console input has to be checked without ever
   -- stalling that loop.
   procedure Try_Get (Item : out Character; Got : out Boolean);

   -- Public so Bifrost.Startup can take its 'Address for the vector
   -- table -- the same role Reset_Handler already plays there. Not
   -- meant to be called directly by anything else.
   procedure Interrupt_Handler
     with Export, Convention => C, External_Name => "USART3_IRQHandler";

end Bifrost.UART;
