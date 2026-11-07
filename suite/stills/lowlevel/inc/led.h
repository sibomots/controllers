// ============================================================================
// Stills -- NUCLEO-F767ZI bare-metal C minimal example.
//
// Copyright (c) 2026 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================
#ifndef __STILLS_LED_H__
#define __STILLS_LED_H__

// User LED LD1 (PB0). See DESIGN.md for the board documentation that
// pins down PB0 as the correct wiring.
void led_init(void);
void led_on(void);
void led_off(void);

#endif
