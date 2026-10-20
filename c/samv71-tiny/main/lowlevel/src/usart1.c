#include "usart1.h"
#include "pio.h"
#include "pmc.h"
#include "board.h"
#include <samv71q21b.h>


#define USART1_BAUD_CD 162u
#define USART1_BAUD_FP 6u

#define USART1_MR_VALUE ((0x3u << 6) | (0x4u << 9))

#define USART1_TX_RING_SIZE 128u

static struct usart_async_descriptor *s_active = 0;

static volatile uint8_t  s_tx_ring[USART1_TX_RING_SIZE];
static volatile uint16_t s_tx_head;
static volatile uint16_t s_tx_tail;

static uint8_t          *s_rx_buf;
static uint16_t          s_rx_buf_len;
static volatile uint16_t s_rx_head;
static volatile uint16_t s_rx_tail;

void *_usart_get_usart_async(void)
{
    return (void *)0;
}

int32_t usart_async_init(struct usart_async_descriptor *const descr, void *const hw, uint8_t *rx_buffer,
                          uint16_t rx_buffer_length, void *const func)
{
    (void)func;

    descr->hw     = hw;
    descr->io.descr = descr;
    descr->tx_cb  = 0;
    descr->rx_cb  = 0;

    s_rx_buf     = rx_buffer;
    s_rx_buf_len = rx_buffer_length;
    s_rx_head = s_rx_tail = 0;
    s_tx_head = s_tx_tail = 0;
    s_active = descr;

    _pmc_enable_periph_clock(ID_USART1);
    gpio_set_pin_function(PA21, GPIO_PIN_FUNCTION_A);
    gpio_set_pin_function(PB4, GPIO_PIN_FUNCTION_D);

    Usart *u = (Usart *)hw;
    u->US_WPMR = US_WPMR_WPKEY_PASSWD;
    u->US_MR   = 0;
    u->US_RTOR = 0;
    u->US_TTGR = 0;
    u->US_CR   = US_CR_RSTRX | US_CR_RXDIS | US_CR_RSTTX | US_CR_TXDIS;
    u->US_CR   = US_CR_RSTSTA;
    u->US_MR   = USART1_MR_VALUE;
    u->US_BRGR = USART1_BAUD_CD | (USART1_BAUD_FP << 16);

    NVIC_EnableIRQ(USART1_IRQn);
    return 0;
}

int32_t usart_async_register_callback(struct usart_async_descriptor *const descr,
                                       const enum usart_async_callback_type type, usart_async_cb_t cb)
{
    if (type == USART_ASYNC_TXC_CB)
        descr->tx_cb = cb;
    else
        descr->rx_cb = cb;
    return 0;
}

int32_t usart_async_get_io_descriptor(struct usart_async_descriptor *const descr, struct io_descriptor **io)
{
    *io = &descr->io;
    return 0;
}

int32_t usart_async_enable(struct usart_async_descriptor *const descr)
{
    Usart *u = (Usart *)descr->hw;
    u->US_IER = US_IER_RXRDY;
    u->US_CR  = US_CR_RXEN | US_CR_TXEN;
    return 0;
}

int32_t io_write(struct io_descriptor *io, const uint8_t *buf, uint16_t length)
{
    (void)io;
    if (length == 0)
        return 0;

    uint16_t next = (uint16_t)((s_tx_head + 1u) % USART1_TX_RING_SIZE);
    if (next == s_tx_tail)
        return 0;

    s_tx_ring[s_tx_head] = buf[0];
    s_tx_head = next;

    ((Usart *)s_active->hw)->US_IER = US_IER_TXRDY;
    return 1;
}

int32_t io_read(struct io_descriptor *io, uint8_t *buf, uint16_t length)
{
    (void)io;
    if (length == 0 || s_rx_head == s_rx_tail)
        return 0;

    buf[0]    = s_rx_buf[s_rx_tail];
    s_rx_tail = (uint16_t)((s_rx_tail + 1u) % s_rx_buf_len);
    return 1;
}

void USART1_Handler(void)
{
    if (s_active == 0)
        return;

    Usart   *u   = (Usart *)s_active->hw;
    uint32_t csr = u->US_CSR;
    uint32_t imr = u->US_IMR;

    if ((csr & US_CSR_TXRDY) && (imr & US_IER_TXRDY))
    {
        if (s_tx_tail != s_tx_head)
        {
            u->US_THR = s_tx_ring[s_tx_tail];
            s_tx_tail = (uint16_t)((s_tx_tail + 1u) % USART1_TX_RING_SIZE);
            if (s_active->tx_cb)
                s_active->tx_cb(s_active);
        }
        else
        {
            u->US_IDR = US_IDR_TXRDY;
        }
        return;
    }

    if ((csr & US_CSR_RXRDY) && (imr & US_IER_RXRDY))
    {
        uint8_t  byte = (uint8_t)u->US_RHR;
        uint16_t next = (uint16_t)((s_rx_head + 1u) % s_rx_buf_len);
        if (next != s_rx_tail)
        {
            s_rx_buf[s_rx_head] = byte;
            s_rx_head = next;
        }
        if (s_active->rx_cb)
            s_active->rx_cb(s_active);
        return;
    }
}
