#ifndef __PIO_H__
#define __PIO_H__

#include <stdint.h>
#include <stdbool.h>
#include "board.h"

enum gpio_direction
{
    GPIO_DIRECTION_OFF,
    GPIO_DIRECTION_IN,
    GPIO_DIRECTION_OUT
};

void gpio_set_pin_direction(uint32_t gpio, enum gpio_direction direction);
void gpio_set_pin_level(uint32_t gpio, bool level);
void gpio_set_pin_function(uint32_t gpio, uint32_t function);

#endif
