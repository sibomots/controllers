// ============================================================================
// This file is part of Bifrost
//
// Copyright (c) 2025 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================
#ifndef __BIFROST_USART3_H__
#define __BIFROST_USART3_H__

// USART3 driver, interrupt-driven in both directions -- the C
// counterpart to the Ada port's Bifrost.UART. USART3 on PD8 (TX) / PD9
// (RX) is the ST-LINK Virtual COM Port on this board (SB5/SB6 ON per
// UM1974, default) -- no hardware rework needed.
//
// USART3_IRQHandler is already declared weak and aliased to
// Default_Handler in config/src/startup_stm32f722.c's vector table (at
// IRQn 39) -- defining a real, non-weak USART3_IRQHandler here is
// enough to override it; no vector-table edits needed, unlike the Ada
// port (which had no full vector table to begin with).

void usart3_init(void);
void usart3_put(char c);
void usart3_put_line(const char *s);

// Non-blocking: returns 1 and writes *out if a byte was waiting,
// returns 0 otherwise. Deliberately not a blocking get -- main's loop
// must keep updating the LCD every iteration, so console input has to
// be checked without ever stalling that loop.
int usart3_try_get(char *out);

#endif
