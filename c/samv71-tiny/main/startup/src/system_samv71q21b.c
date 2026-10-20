
#include "samv71q21b.h"

#ifdef __cplusplus
extern "C" {
#endif

#define __SYSTEM_CLOCK    (12000000)

uint32_t SystemCoreClock = __SYSTEM_CLOCK;

void SystemInit(void)
{
    SystemCoreClock = __SYSTEM_CLOCK;
    return;
}

void SystemCoreClockUpdate(void)
{
    SystemCoreClock = __SYSTEM_CLOCK;
    return;
}

#ifdef __cplusplus
}
#endif
