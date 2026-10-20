#include "driver_init.h"
#include "chip_init.h"
#include "pio.h"
#include "wdt.h"
#include "tc0.h"


void system_init(void)
{
    init_mcu();
    wdt_disable();

    gpio_set_pin_level(LED0, true);
    gpio_set_pin_level(LED1, true);

    gpio_set_pin_direction(LED0, GPIO_DIRECTION_OUT);
    gpio_set_pin_direction(LED1, GPIO_DIRECTION_OUT);

    gpio_set_pin_function(LED0, GPIO_PIN_FUNCTION_OFF);
    gpio_set_pin_function(LED1, GPIO_PIN_FUNCTION_OFF);

    tc0_channel0_init();
}
