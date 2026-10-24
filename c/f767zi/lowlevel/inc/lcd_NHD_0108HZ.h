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
#ifndef __BIFROST_LCD_NHD_0108HZ_H__
#define __BIFROST_LCD_NHD_0108HZ_H__

#include <stdint.h>

void lcd_gpio_init(void);
void lcd_set_bit(uint32_t bit);
void lcd_clear_bit(uint32_t bit);
void lcd_write_nibble(uint8_t nibble, uint8_t is_data);
void lcd_write_byte(uint8_t value, uint8_t is_data);
void lcd_write_cmd(uint8_t cmd);
void lcd_write_data(uint8_t data);

#endif
