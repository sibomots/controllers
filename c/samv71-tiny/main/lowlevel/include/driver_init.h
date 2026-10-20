#ifndef DRIVER_INIT_H_INCLUDED
#define DRIVER_INIT_H_INCLUDED


#include "atmel_start_pins.h"
#include "pio.h"
#include "usart1.h"

extern struct usart_async_descriptor EDBG_COM;

void EDBG_COM_PORT_init(void);
void EDBG_COM_CLOCK_init(void);
void EDBG_COM_init(void);

void system_init(void);

#endif
