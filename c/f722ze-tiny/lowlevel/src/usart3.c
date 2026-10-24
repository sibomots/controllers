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
#include "gpio.h"
#include "usart3.h"

#define TX_RING_SIZE 128U
#define RX_RING_SIZE 16U

#define RXNE_BIT (1U << 5)
#define TXE_BIT (1U << 7)
#define RE_BIT (1U << 2)
#define RXNEIE_BIT (1U << 5)
#define TXEIE_BIT (1U << 7)

// Lock-free single-producer/single-consumer ring buffers. Safe because
// each buffer has exactly one writer and one reader: the TX ring is
// written only by usart3_put (foreground) and drained only by
// USART3_IRQHandler (ISR); the RX ring is written only by
// USART3_IRQHandler and drained only by usart3_try_get. Classic "one
// slot wasted" ring design: empty when head == tail, full when
// advancing head would reach tail -- no separate count variable
// needed, which would itself need synchronizing between the two sides.
static volatile char tx_buf[TX_RING_SIZE];
static volatile uint8_t tx_head = 0; // written by usart3_put only
static volatile uint8_t tx_tail = 0; // written by the ISR only

static volatile char rx_buf[RX_RING_SIZE];
static volatile uint8_t rx_head = 0; // written by the ISR only
static volatile uint8_t rx_tail = 0; // written by usart3_try_get only

void usart3_init(void)
{
    *RCC_AHB1ENR |= (1U << GPIODEN_BIT);
    *RCC_APB1ENR |= (1U << USART3EN_BIT);

    // PD8, PD9 to alternate-function mode (binary "10" per pin).
    // Combined 4-bit field at bits[19:16] (pin9 high nibble bits, pin8
    // low nibble bits) = "1010" = 0xA.
    *GPIOD_MODER = (*GPIOD_MODER & ~0x000F0000UL) | 0x000A0000UL;

    // AF7 (USART3) on PD8 (AFRH bits[3:0]) and PD9 (AFRH bits[7:4]).
    *GPIOD_AFRH = (*GPIOD_AFRH & ~0x000000FFUL) | 0x00000077UL;

    // 115200 baud at the default reset clock (HSI 16 MHz, no PLL --
    // SystemInit is a no-op). BRR = PCLK1 / Baud = 16_000_000 / 115200.
    *USART3_BRR = 139;

    // UE (bit 0) + TE (bit 3) + RE (bit 2) + RXNEIE (bit 5). TXEIE is
    // enabled on demand by usart3_put, not here -- nothing to transmit
    // yet.
    *USART3_CR1 = (1U << 0) | (1U << 3) | RE_BIT | RXNEIE_BIT;

    // Enable USART3's NVIC line (IRQn 39, bit 7 of ISER1). Until this
    // is set, USART3_IRQHandler cannot fire regardless of what the
    // vector table points at.
    *NVIC_ISER1 |= (1U << (USART3_IRQn - 32));
}

void usart3_put(char c)
{
    uint8_t next = (uint8_t)((tx_head + 1) % TX_RING_SIZE);
    while (next == tx_tail) {
        // Ring full -- wait for the ISR to drain a slot rather than
        // drop the byte (a longer message than the ring can hold at
        // once must still arrive intact). TXEIE has to be enabled for
        // the ISR to run at all; enabling it unconditionally here also
        // covers the case where this is the very first byte ever
        // queued.
        *USART3_CR1 |= TXEIE_BIT;
    }
    tx_buf[tx_head] = c;
    tx_head = next;
    *USART3_CR1 |= TXEIE_BIT;
}

void usart3_put_line(const char *s)
{
    while (*s) {
        usart3_put(*s);
        s++;
    }
    usart3_put('\r');
    usart3_put('\n');
}

int usart3_try_get(char *out)
{
    if (rx_head == rx_tail) {
        return 0;
    }
    *out = rx_buf[rx_tail];
    rx_tail = (uint8_t)((rx_tail + 1) % RX_RING_SIZE);
    return 1;
}

void USART3_IRQHandler(void)
{
    if (*USART3_ISR & RXNE_BIT) {
        char c = (char)(*USART3_RDR & 0xFF); // reading RDR self-clears RXNE
        uint8_t next = (uint8_t)((rx_head + 1) % RX_RING_SIZE);
        if (next != rx_tail) {
            rx_buf[rx_head] = c;
            rx_head = next;
        } // else: ring full, drop the byte
    }

    if (*USART3_ISR & TXE_BIT) {
        if (tx_head != tx_tail) {
            *USART3_TDR = (uint32_t)(uint8_t)tx_buf[tx_tail];
            tx_tail = (uint8_t)((tx_tail + 1) % TX_RING_SIZE);
        } else {
            *USART3_CR1 &= ~TXEIE_BIT;
        }
    }
}
