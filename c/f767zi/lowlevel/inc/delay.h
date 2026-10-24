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
#ifndef __BIFROST_DELAY_H__
#define __BIFROST_DELAY_H__

void delay(volatile uint32_t count);
void delay_us(volatile uint32_t us);
void delay_ms(volatile uint32_t ms);

#endif

