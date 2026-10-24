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
#include "usart3.h"
#include "lcd_string.h"
#include "lcd_config.h"
#include "tinymon.h"

#define BUF_SIZE 64U
#define BS (0x08)
#define DEL (0x7F)
#define CR ('\r')

#define PLATFORM_DESC "NUCLEO-F767ZI (STM32F767ZI)"

/* Hand-edit this on each release. Deliberately not derived from the
 * git commit SHA -- a build can't know the SHA of the commit that
 * will contain it, and a plain string avoids that chicken-and-egg
 * problem entirely. */
#define SOFTWARE_VERSION "0.1.0"

#define LICENSE_TEXT \
    "Copyright (c) 2025 Jeff Wandling. All rights reserved. | BSD 3-Clause License"

static char buffer[BUF_SIZE];
static unsigned int idx = 0;

// A mirror of main's own counter, kept current via tinymon_set_counter
// each loop iteration -- not the literal variable. One accepted
// consequence: update_lcd_disp_string resets its counter argument to 0
// on rollover (at LCD_MAX_NUM); calling it here on live_counter only
// resets this mirror, not main's real counter. Harmless -- the next
// main-loop iteration resyncs this mirror anyway, and actually reaching
// LCD_MAX_NUM (99,999,999) takes a very long time at this increment
// rate.
static uint32_t live_counter = 0;

static void put_string(const char *s)
{
    while (*s) {
        usart3_put(*s);
        s++;
    }
}

static void show_prompt(void)
{
    put_string("\r\nTinyMon> ");
}

static void show_help(void)
{
    put_string("\r\n\n" PLATFORM_DESC "\r\n"
               "Version " SOFTWARE_VERSION "\r\n"
               LICENSE_TEXT "\r\n\n"
               "Available commands:\r\nhelp\r\ncount\r\nlicense\r\n");
}

static void show_license(void)
{
    put_string("\r\n" LICENSE_TEXT "\r\n");
}

static void show_count(void)
{
    char count_buf[LCD_MAX_COL + 1];
    update_lcd_disp_string(count_buf, &live_counter);
    put_string("\r\n");
    put_string(count_buf);
    put_string("\r\n");
}

static void clear_buffer(void)
{
    idx = 0;
}

// buffer[0 .. len-1] exactly equal to the literal cmd -- a hand-rolled
// check rather than strcmp, matching this codebase's existing style
// (e.g. lcd_string.c does its own digit extraction rather than reaching
// for snprintf).
static int cmd_is(const char *cmd)
{
    unsigned int i;
    for (i = 0; i < idx; i++) {
        if (cmd[i] == 0 || buffer[i] != cmd[i]) {
            return 0;
        }
    }
    return cmd[i] == 0;
}

static void dispatch_cmd(void)
{
    if (cmd_is("help")) {
        show_help();
    } else if (cmd_is("count")) {
        show_count();
    } else if (cmd_is("license")) {
        show_license();
    } else {
        put_string("\r\nunknown command\r\n");
    }

    clear_buffer();
    show_prompt();
}

static void tinymon_parse(char c)
{
    if (idx >= BUF_SIZE) {
        return;
    }

    switch (c) {
    case BS:
    case DEL:
        if (idx > 0) {
            put_string("\x08 \x08");
            idx--;
        }
        break;

    case CR:
        if (idx > 0) {
            dispatch_cmd();
        } else {
            clear_buffer();
            show_prompt();
        }
        break;

    default:
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9')) {
            usart3_put(c);
            buffer[idx++] = c;
        }
        break;
    }
}

void tinymon_set_counter(uint32_t value)
{
    live_counter = value;
}

void tinymon_poll(void)
{
    char c;
    if (usart3_try_get(&c)) {
        tinymon_parse(c);
    }
}

void tinymon_init(void)
{
    usart3_init();
    put_string("\r\n\r\nThis is TinyMon\r\n"
               PLATFORM_DESC "\r\n"
               "Version " SOFTWARE_VERSION "\r\n"
               LICENSE_TEXT "\r\n\r\n"
               "Type 'help' for more information.\r\n\r\n");
    show_prompt();
}
