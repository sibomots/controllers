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
#ifndef __BIFROST_LCD_CONTROL_H__
#define __BIFROST_LCD_CONTROL_H__
// --- High-level helpers
void lcd_clear(void);
void lcd_home(void);

// For NHD-0108 (8x1), DDRAM column addresses are 0x00..0x07
void lcd_set_cursor(uint8_t col);
void lcd_write_char(char c);
void lcd_write_string(const char *s);
void lcd_init(void);

#endif
