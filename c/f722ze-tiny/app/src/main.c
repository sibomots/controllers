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
#include "sleep.h"
#include "lcd_control.h"
#include "lcd_string.h"
#include "tinymon.h"

int main(void)
{
    lcd_init();
    tinymon_init();

	lcd_set_cursor(0);
    lcd_write_string("BIFROST");
    sleep(500);
    lcd_clear();

    uint32_t c = 0;
    char display[LCD_MAX_COL+1];
    while (1) {
        sleep(5);
        update_lcd_disp_string((char*)display, &c);
	    lcd_set_cursor(0);
		lcd_write_string((const char*)display);
		c++;
        tinymon_set_counter(c);
        tinymon_poll();
    }
}
