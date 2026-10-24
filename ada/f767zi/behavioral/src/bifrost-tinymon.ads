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

-- TinyMon console -- this is the "UART Sink" half of the Main/LCD_Sink/
-- UART_Sink split ../../SOFTWARE.md plans for. Structural change from
-- ../../f722ze-tiny's Bifrost.TinyMon: there, with no tasking runtime at
-- all, Parse had to be polled non-blockingly once per iteration of
-- Main's own loop (Bifrost.UART.Try_Get, checked alongside the LCD
-- update). Here, a library-level task (declared in the body, named
-- UART_Sink per ../../SOFTWARE.md's own vocabulary) blocks directly on
-- Bifrost.UART.Get -- a real Ravenscar protected entry -- genuinely
-- event-driven, not polled, the same structural improvement
-- ada/samv71-tiny's Console task already demonstrated for its board.
package Bifrost.TinyMon is

   -- Shows the welcome banner and the first prompt. Call once from Main,
   -- after Bifrost.UART.Initialize -- not automatically at elaboration,
   -- because UART_Sink (which starts automatically) would otherwise race
   -- USART3's own hardware bring-up. Same ordering contract
   -- ada/samv71-tiny's Samv71_Tiny.TinyMon.Show_Welcome documents.
   procedure Show_Welcome;

   -- Call from Bifrost.LCD_Sink's periodic task each time the displayed
   -- counter advances, so the "count" command's answer stays current.
   -- See the body for how this is safely shared cross-task without a
   -- protected object.
   procedure Set_Counter (Value : Natural);

end Bifrost.TinyMon;
