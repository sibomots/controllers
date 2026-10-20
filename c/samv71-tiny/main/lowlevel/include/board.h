#ifndef __BOARD_H__
#define __BOARD_H__

#include <stdint.h>

#define GPIO_PORTA 0
#define GPIO_PORTB 1
#define GPIO_PORTC 2
#define GPIO_PORTD 3
#define GPIO_PORTE 4
#define GPIO(port, pin) (((port) << 8) | (pin))
#define GPIO_PORT(gpio) ((gpio) >> 8)
#define GPIO_PIN(gpio) ((gpio)&0xFFU)

#define GPIO_PIN_FUNCTION_A 0
#define GPIO_PIN_FUNCTION_B 1
#define GPIO_PIN_FUNCTION_C 2
#define GPIO_PIN_FUNCTION_D 3
#define GPIO_PIN_FUNCTION_OFF 0xFFFFFFFFU

#define PA21 GPIO(GPIO_PORTA, 21)
#define PB4 GPIO(GPIO_PORTB, 4)
#define PC31 GPIO(GPIO_PORTC, 31)
#define SW0 GPIO(GPIO_PORTA, 9)
#define LED0 GPIO(GPIO_PORTA, 23)
#define LED1 GPIO(GPIO_PORTC, 9)
#define GPIO1_HB GPIO(GPIO_PORTB, 3)

#endif
