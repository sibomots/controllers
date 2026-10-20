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
#ifndef __BIFROST_LCD_STRING_H__
#define __BIFROST_LCD_STRING_H__

#include <stdint.h>
#include "lcd_config.h"

void  update_lcd_disp_string(char* pdest, uint32_t* pcounter);
#endif
