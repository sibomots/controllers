#include "chip_init.h"
#include <samv71q21b.h>


#define PLL_COUNT 0x3fU

void init_mcu(void)
{
    SCB->CPACR |= (0xFU << 20);
    __DSB();
    __ISB();

    EFC->EEFC_FMR = (EFC->EEFC_FMR & ~EEFC_FMR_FWS_Msk) | EEFC_FMR_FWS(5);

    uint32_t mor = PMC->CKGR_MOR;
    mor = (mor & ~CKGR_MOR_MOSCXTBY_Msk) | CKGR_MOR_KEY_PASSWD | CKGR_MOR_MOSCXTEN | CKGR_MOR_MOSCXTST(62);
    PMC->CKGR_MOR = mor;
    while (!(PMC->PMC_SR & PMC_SR_MOSCXTS_Msk))
    {
    }
    PMC->CKGR_MOR = CKGR_MOR_KEY_PASSWD | (PMC->CKGR_MOR | CKGR_MOR_MOSCSEL);

    PMC->CKGR_PLLAR = CKGR_PLLAR_ONE | CKGR_PLLAR_MULA(24) | CKGR_PLLAR_DIVA(1) | CKGR_PLLAR_PLLACOUNT(PLL_COUNT);
    while (!(PMC->PMC_SR & PMC_SR_LOCKA_Msk))
    {
    }

    PMC->PMC_MCKR = (PMC->PMC_MCKR & ~PMC_MCKR_PRES_Msk) | PMC_MCKR_PRES_CLK_1;
    while (!(PMC->PMC_SR & PMC_SR_MCKRDY_Msk))
    {
    }
    PMC->PMC_MCKR = (PMC->PMC_MCKR & ~PMC_MCKR_MDIV_Msk) | PMC_MCKR_MDIV_PCK_DIV3;
    while (!(PMC->PMC_SR & PMC_SR_MCKRDY_Msk))
    {
    }
    PMC->PMC_MCKR = (PMC->PMC_MCKR & ~PMC_MCKR_CSS_Msk) | PMC_MCKR_CSS_PLLA_CLK;
    while (!(PMC->PMC_SR & PMC_SR_MCKRDY_Msk))
    {
    }
}
