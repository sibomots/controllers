#include "pio.h"
#include <samv71q21b.h>


static Pio *port_to_reg(uint8_t port)
{
    return (Pio *)((uint32_t)PIOA + port * 0x200U);
}

void gpio_set_pin_direction(uint32_t gpio, enum gpio_direction direction)
{
    Pio     *hw   = port_to_reg((uint8_t)GPIO_PORT(gpio));
    uint32_t mask = 1U << GPIO_PIN(gpio);

    switch (direction)
    {
    case GPIO_DIRECTION_OUT:
        hw->PIO_OER = mask;
        break;
    case GPIO_DIRECTION_IN:
    case GPIO_DIRECTION_OFF:
    default:
        hw->PIO_ODR = mask;
        break;
    }
}

void gpio_set_pin_level(uint32_t gpio, bool level)
{
    Pio     *hw   = port_to_reg((uint8_t)GPIO_PORT(gpio));
    uint32_t mask = 1U << GPIO_PIN(gpio);

    if (level)
        hw->PIO_SODR = mask;
    else
        hw->PIO_CODR = mask;
}

void gpio_set_pin_function(uint32_t gpio, uint32_t function)
{
    uint8_t  port = (uint8_t)GPIO_PORT(gpio);
    uint8_t  pin  = (uint8_t)GPIO_PIN(gpio);
    Pio     *hw   = port_to_reg(port);
    uint32_t mask = 1U << pin;

    if (port == GPIO_PORTB && (pin == 4 || pin == 5 || pin == 6 || pin == 7 || pin == 12))
    {
        MATRIX->CCFG_SYSIO |= (1U << pin);
    }

    if (function == GPIO_PIN_FUNCTION_OFF)
    {
        hw->PIO_PER = mask;
        return;
    }

    if (function & 0x1U)
        hw->PIO_ABCDSR[0] |= mask;
    else
        hw->PIO_ABCDSR[0] &= ~mask;

    if (function & 0x2U)
        hw->PIO_ABCDSR[1] |= mask;
    else
        hw->PIO_ABCDSR[1] &= ~mask;

    hw->PIO_PDR = mask;
}
