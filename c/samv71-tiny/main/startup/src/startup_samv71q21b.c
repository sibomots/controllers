
#include "samv71q21b.h"

extern uint32_t _sfixed;
extern uint32_t _efixed;
extern uint32_t _etext;
extern uint32_t _srelocate;
extern uint32_t _erelocate;
extern uint32_t _szero;
extern uint32_t _ezero;
extern uint32_t _sstack;
extern uint32_t _estack;

int main(void);

void __libc_init_array(void);

void Reset_Handler(void);

void Dummy_Handler(void);

void NonMaskableInt_Handler ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void HardFault_Handler    ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MemoryManagement_Handler ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void BusFault_Handler     ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UsageFault_Handler   ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SVCall_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void DebugMonitor_Handler ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PendSV_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SysTick_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));

void SUPC_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void RSTC_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void RTC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void RTT_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void WDT_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PMC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void EFC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UART0_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UART1_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PIOA_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PIOB_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PIOC_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void USART0_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void USART1_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void USART2_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PIOD_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PIOE_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void HSMCI_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TWIHS0_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TWIHS1_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SPI0_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SSC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC0_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC1_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC2_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC3_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC4_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC5_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void AFEC0_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void DACC_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PWM0_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void ICM_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void ACC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void USBHS_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MCAN0_INT0_Handler   ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MCAN0_INT1_Handler   ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MCAN1_INT0_Handler   ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MCAN1_INT1_Handler   ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void AFEC1_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TWIHS2_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SPI1_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void QSPI_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UART2_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UART3_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void UART4_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC6_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC7_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC8_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC9_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC10_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TC11_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void MLB_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void AES_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void TRNG_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void XDMAC_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void ISI_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void PWM1_Handler         ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void FPU_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void SDRAMC_Handler       ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void RSWDT_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void CCW_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void CCF_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Q1_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Q2_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void IXC_Handler          ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void I2SC0_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void I2SC1_Handler        ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Q3_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Q4_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));
void GMAC_Q5_Handler      ( void ) __attribute__ ((weak, alias("Dummy_Handler")));

__attribute__ ((section(".vectors")))
const DeviceVectors exception_table = {

        .pvStack = (void*) (&_estack),

        .pfnReset_Handler              = (void*) Reset_Handler,
        .pfnNonMaskableInt_Handler     = (void*) NonMaskableInt_Handler,
        .pfnHardFault_Handler          = (void*) HardFault_Handler,
        .pfnMemoryManagement_Handler   = (void*) MemoryManagement_Handler,
        .pfnBusFault_Handler           = (void*) BusFault_Handler,
        .pfnUsageFault_Handler         = (void*) UsageFault_Handler,
        .pvReservedC9                  = (void*) (0UL),
        .pvReservedC8                  = (void*) (0UL),
        .pvReservedC7                  = (void*) (0UL),
        .pvReservedC6                  = (void*) (0UL),
        .pfnSVCall_Handler             = (void*) SVCall_Handler,
        .pfnDebugMonitor_Handler       = (void*) DebugMonitor_Handler,
        .pvReservedC3                  = (void*) (0UL),
        .pfnPendSV_Handler             = (void*) PendSV_Handler,
        .pfnSysTick_Handler            = (void*) SysTick_Handler,

        .pfnSUPC_Handler               = (void*) SUPC_Handler,
        .pfnRSTC_Handler               = (void*) RSTC_Handler,
        .pfnRTC_Handler                = (void*) RTC_Handler,
        .pfnRTT_Handler                = (void*) RTT_Handler,
        .pfnWDT_Handler                = (void*) WDT_Handler,
        .pfnPMC_Handler                = (void*) PMC_Handler,
        .pfnEFC_Handler                = (void*) EFC_Handler,
        .pfnUART0_Handler              = (void*) UART0_Handler,
        .pfnUART1_Handler              = (void*) UART1_Handler,
        .pvReserved9                   = (void*) (0UL),
        .pfnPIOA_Handler               = (void*) PIOA_Handler,
        .pfnPIOB_Handler               = (void*) PIOB_Handler,
        .pfnPIOC_Handler               = (void*) PIOC_Handler,
        .pfnUSART0_Handler             = (void*) USART0_Handler,
        .pfnUSART1_Handler             = (void*) USART1_Handler,
        .pfnUSART2_Handler             = (void*) USART2_Handler,
        .pfnPIOD_Handler               = (void*) PIOD_Handler,
        .pfnPIOE_Handler               = (void*) PIOE_Handler,
        .pfnHSMCI_Handler              = (void*) HSMCI_Handler,
        .pfnTWIHS0_Handler             = (void*) TWIHS0_Handler,
        .pfnTWIHS1_Handler             = (void*) TWIHS1_Handler,
        .pfnSPI0_Handler               = (void*) SPI0_Handler,
        .pfnSSC_Handler                = (void*) SSC_Handler,
        .pfnTC0_Handler                = (void*) TC0_Handler,
        .pfnTC1_Handler                = (void*) TC1_Handler,
        .pfnTC2_Handler                = (void*) TC2_Handler,
        .pfnTC3_Handler                = (void*) TC3_Handler,
        .pfnTC4_Handler                = (void*) TC4_Handler,
        .pfnTC5_Handler                = (void*) TC5_Handler,
        .pfnAFEC0_Handler              = (void*) AFEC0_Handler,
        .pfnDACC_Handler               = (void*) DACC_Handler,
        .pfnPWM0_Handler               = (void*) PWM0_Handler,
        .pfnICM_Handler                = (void*) ICM_Handler,
        .pfnACC_Handler                = (void*) ACC_Handler,
        .pfnUSBHS_Handler              = (void*) USBHS_Handler,
        .pfnMCAN0_INT0_Handler         = (void*) MCAN0_INT0_Handler,
        .pfnMCAN0_INT1_Handler         = (void*) MCAN0_INT1_Handler,
        .pfnMCAN1_INT0_Handler         = (void*) MCAN1_INT0_Handler,
        .pfnMCAN1_INT1_Handler         = (void*) MCAN1_INT1_Handler,
        .pfnGMAC_Handler               = (void*) GMAC_Handler,
        .pfnAFEC1_Handler              = (void*) AFEC1_Handler,
        .pfnTWIHS2_Handler             = (void*) TWIHS2_Handler,
        .pfnSPI1_Handler               = (void*) SPI1_Handler,
        .pfnQSPI_Handler               = (void*) QSPI_Handler,
        .pfnUART2_Handler              = (void*) UART2_Handler,
        .pfnUART3_Handler              = (void*) UART3_Handler,
        .pfnUART4_Handler              = (void*) UART4_Handler,
        .pfnTC6_Handler                = (void*) TC6_Handler,
        .pfnTC7_Handler                = (void*) TC7_Handler,
        .pfnTC8_Handler                = (void*) TC8_Handler,
        .pfnTC9_Handler                = (void*) TC9_Handler,
        .pfnTC10_Handler               = (void*) TC10_Handler,
        .pfnTC11_Handler               = (void*) TC11_Handler,
        .pfnMLB_Handler                = (void*) MLB_Handler,
        .pvReserved54                  = (void*) (0UL),
        .pvReserved55                  = (void*) (0UL),
        .pfnAES_Handler                = (void*) AES_Handler,
        .pfnTRNG_Handler               = (void*) TRNG_Handler,
        .pfnXDMAC_Handler              = (void*) XDMAC_Handler,
        .pfnISI_Handler                = (void*) ISI_Handler,
        .pfnPWM1_Handler               = (void*) PWM1_Handler,
        .pfnFPU_Handler                = (void*) FPU_Handler,
        .pfnSDRAMC_Handler             = (void*) SDRAMC_Handler,
        .pfnRSWDT_Handler              = (void*) RSWDT_Handler,
        .pfnCCW_Handler                = (void*) CCW_Handler,
        .pfnCCF_Handler                = (void*) CCF_Handler,
        .pfnGMAC_Q1_Handler            = (void*) GMAC_Q1_Handler,
        .pfnGMAC_Q2_Handler            = (void*) GMAC_Q2_Handler,
        .pfnIXC_Handler                = (void*) IXC_Handler,
        .pfnI2SC0_Handler              = (void*) I2SC0_Handler,
        .pfnI2SC1_Handler              = (void*) I2SC1_Handler,
        .pfnGMAC_Q3_Handler            = (void*) GMAC_Q3_Handler,
        .pfnGMAC_Q4_Handler            = (void*) GMAC_Q4_Handler,
        .pfnGMAC_Q5_Handler            = (void*) GMAC_Q5_Handler
};

void Reset_Handler(void)
{
        uint32_t *pSrc, *pDest;

        pSrc = &_etext;
        pDest = &_srelocate;

        if (pSrc != pDest) {
                for (; pDest < &_erelocate;) {
                        *pDest++ = *pSrc++;
                }
        }

        for (pDest = &_szero; pDest < &_ezero;) {
                *pDest++ = 0;
        }

        pSrc = (uint32_t *) & _sfixed;
        SCB->VTOR = ((uint32_t) pSrc & SCB_VTOR_TBLOFF_Msk);

        __libc_init_array();

        main();

        while (1);
}

void Dummy_Handler(void)
{
        while (1) {
        }
}
