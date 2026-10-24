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

-- Board-specific constants for the NUCLEO-F767ZI, STM32F767ZI.
--
-- Unlike ../../f722ze-tiny/lowlevel/board/stm32f722ze/src/bifrost-board.ads,
-- this file holds no raw register addresses at all -- light-tasking-
-- stm32f769disco bundles a real SVD-generated BSP (Interfaces.STM32.RCC/
-- .GPIO/.USART), confirmed directly against files on disk under the
-- installed toolchain's gnat/ directory, so Bifrost.UART and Bifrost.LCD
-- reference those typed, address-mapped peripheral records directly
-- instead of hand-rolled Address-imported overlays. What's left here is
-- exactly what ada/samv71-tiny/lowlevel/src/samv71_tiny-board.ads carries
-- for the same reason: pin-number mnemonics and anything the bundled BSP
-- doesn't already name.
--
-- Pin assignments below are carried forward unchanged from
-- ../../f722ze-tiny's board file, on the basis that NUCLEO-F767ZI shares
-- the NUCLEO-144 family's standardized Zio/Morpho connector layout with
-- NUCLEO-F722ZE -- NOT independently re-verified against F767ZI's own
-- UM1974 pinout tables yet (no board in hand at the time of this port;
-- see ../../../HARDWARE.md). Re-verify before trusting on real hardware,
-- same caveat ../../../HARDWARE.md already carries for F722ZE<->F767ZI
-- porting in general.
package Bifrost.Board is

   -- logical name, NUCLEO pin, display pin number (NHD-0108HZ-FSW-GBW):
   LCD_DB4  : constant := 10; -- PB10, display pin 6
   LCD_DB5  : constant := 4;  -- PB4,  display pin 7
   LCD_DB6  : constant := 5;  -- PB5,  display pin 8
   LCD_DB7  : constant := 3;  -- PB3,  display pin 9
   LCD_E    : constant := 2;  -- PB2,  display pin 5
   LCD_RDWR : constant := 1;  -- PB1,  display pin 4
   LCD_DI   : constant := 15; -- PB15, display pin 3
   -- display pins 2 and 1 are power; pins 10 and 11 are backlight power.

   -- USART3 TX/RX pin assignment (ST-LINK Virtual COM Port on every
   -- NUCLEO-144 board, PD8/PD9, AF7) -- same as F722ZE; standard across
   -- the NUCLEO-144 family's VCP wiring, not board-specific.
   USART3_TX_Pin : constant := 8;  -- PD8
   USART3_RX_Pin : constant := 9;  -- PD9
   USART3_AF     : constant := 7; -- AF7 selects USART1/2/3 on the F7 family

end Bifrost.Board;
