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
#include <stdint.h>

void delay(volatile uint32_t count)
{
   while(count--) {
	   asm("nop");
   }
}

void delay_us(volatile uint32_t us)
{
   us = us + (us << 2);
   while (us--)
   {
	   asm("nop");
   }
}

void delay_ms(volatile uint32_t ms)
{
	ms = (ms << 12) + (ms << 11) + (ms << 10) + (ms << 8) + (ms << 7) + (ms << 6) + (ms << 5) + (ms << 3);
	while(ms--) {
		asm("nop");
	}
}
