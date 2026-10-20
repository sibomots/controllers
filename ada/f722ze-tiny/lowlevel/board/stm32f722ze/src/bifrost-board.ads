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

-- Board-specific constants (register base addresses, pin assignments)
-- for the NUCLEO-F722ZE, STM32F722ZET6. This is the ONLY file that
-- knows these addresses -- Bifrost.UART and Bifrost.LCD both `with`
-- this package rather than inlining their own copies.
--
-- This file lives under lowlevel/board/stm32f722ze/src/, selected by
-- bifrost.gpr's "Board" scenario variable (default "stm32f722ze"). A
-- different board gets a sibling directory with its own
-- Bifrost.Board -- gprbuild only ever puts one board's directory into
-- Source_Dirs for a given build, so the wrong board's constants are
-- never in the compiled closure to begin with, not merely present and
-- guarded.
--
-- NUCLEO-F722ZE is not the preferred board for Ada going forward (see
-- HARDWARE.md at the repo root) -- NUCLEO-F767ZI is, once in hand, for
-- the tasking work. This board's entry stays as-is; it's what the
-- current UART/LCD work was actually built and proven on.
package Bifrost.Board is

   -- RCC (Reset and Clock Control) -- shared by both GPIOB (LCD) and
   -- GPIOD (UART) clock-enable bits.
   RCC_AHB1ENR_Addr : constant := 16#4002_3830#;

   -- GPIOB -- LCD data/control lines (NHD-0108HZ-FSW-GBW, 4-bit mode)
   GPIOB_MODER_Addr : constant := 16#4002_0400#;
   GPIOB_ODR_Addr   : constant := 16#4002_0414#;
   GPIOBEN_Bit      : constant := 1; -- RCC_AHB1ENR bit 1

   -- logical name, NUCLEO pin, display pin number:
   LCD_DB4  : constant := 10; -- PB10, display pin 6
   LCD_DB5  : constant := 4;  -- PB4,  display pin 7
   LCD_DB6  : constant := 5;  -- PB5,  display pin 8
   LCD_DB7  : constant := 3;  -- PB3,  display pin 9
   LCD_E    : constant := 2;  -- PB2,  display pin 5
   LCD_RDWR : constant := 1;  -- PB1,  display pin 4
   LCD_DI   : constant := 15; -- PB15, display pin 3
   -- display pins 2 and 1 are power; pins 10 and 11 are backlight power.

   -- GPIOD -- USART3 TX/RX (ST-LINK Virtual COM Port on this board)
   GPIOD_MODER_Addr : constant := 16#4002_0C00#;
   GPIOD_AFRH_Addr  : constant := 16#4002_0C24#;
   GPIODEN_Bit      : constant := 3; -- RCC_AHB1ENR bit 3

   -- USART3 ("new" IP: separate ISR/TDR, not legacy SR/DR -- RM0431)
   USART3_CR1_Addr : constant := 16#4000_4800#;
   USART3_BRR_Addr : constant := 16#4000_480C#;
   USART3_ISR_Addr : constant := 16#4000_481C#;
   USART3_RDR_Addr : constant := 16#4000_4824#;
   USART3_TDR_Addr : constant := 16#4000_4828#;
   USART3EN_Bit    : constant := 18; -- RCC_APB1ENR bit 18
   USART3_IRQn     : constant := 39; -- RM0431 Table 36, cross-checked
                                      -- against the C vector table

   RCC_APB1ENR_Addr : constant := 16#4002_3840#;

   -- NVIC (Nested Vectored Interrupt Controller) interrupt set-enable
   -- register covering IRQ32-63. Not RM0431-sourced -- RM0431 defers
   -- NVIC programming to the Cortex-M7 Programming Manual (PM0253),
   -- which isn't in this repo. This address is fixed by the ARMv7-M
   -- architecture itself, identical across every Cortex-M3/4/7
   -- regardless of vendor -- already used and confirmed this session
   -- for a different vendor's chip (Interfaces.SAM.NVIC_Base =
   -- 16#E000_E100# for the SAMV71).
   NVIC_ISER1_Addr : constant := 16#E000_E104#;

end Bifrost.Board;
