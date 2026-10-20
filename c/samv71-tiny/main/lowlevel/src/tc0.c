#include "tc0.h"
#include "pmc.h"
#include <samv71q21b.h>

void tc0_channel0_init(void)
{
    _pmc_enable_periph_clock(ID_TC0_CHANNEL0);
}
