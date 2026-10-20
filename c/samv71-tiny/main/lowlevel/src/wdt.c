#include "wdt.h"
#include <samv71q21b.h>

void wdt_disable(void)
{
    WDT->WDT_MR |= WDT_MR_WDDIS;
}
