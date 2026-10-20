#include "pmc.h"
#include <samv71q21b.h>

void _pmc_enable_periph_clock(uint32_t periph_id)
{
    if (periph_id < 32)
    {
        PMC->PMC_PCER0 = (1U << periph_id);
    }
    else if (periph_id < 64)
    {
        PMC->PMC_PCER1 = (1U << (periph_id - 32U));
    }
}
