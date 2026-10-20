#ifndef __USART1_H__
#define __USART1_H__

#include <stdint.h>


struct usart_async_descriptor;

struct io_descriptor
{
    struct usart_async_descriptor *descr;
};

typedef void (*usart_async_cb_t)(const struct usart_async_descriptor *const descr);

enum usart_async_callback_type
{
    USART_ASYNC_TXC_CB,
    USART_ASYNC_RXC_CB
};

struct usart_async_descriptor
{
    void                 *hw;
    struct io_descriptor  io;
    usart_async_cb_t      tx_cb;
    usart_async_cb_t      rx_cb;
};

int32_t usart_async_init(struct usart_async_descriptor *const descr, void *const hw, uint8_t *rx_buffer,
                          uint16_t rx_buffer_length, void *const func);
int32_t usart_async_register_callback(struct usart_async_descriptor *const descr,
                                       const enum usart_async_callback_type type, usart_async_cb_t cb);
int32_t usart_async_get_io_descriptor(struct usart_async_descriptor *const descr, struct io_descriptor **io);
int32_t usart_async_enable(struct usart_async_descriptor *const descr);

int32_t io_write(struct io_descriptor *io, const uint8_t *buf, uint16_t length);
int32_t io_read(struct io_descriptor *io, uint8_t *buf, uint16_t length);

void *_usart_get_usart_async(void);

#endif
