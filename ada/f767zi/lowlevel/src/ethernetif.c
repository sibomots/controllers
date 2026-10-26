/* ============================================================================
 * This file is part of Bifrost
 *
 * Copyright (c) 2025 Jeff Wandling
 * All Rights Reserved.
 *
 * Licensed under BSD 3-Clause
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted under the terms of the BSD 3-Clause license.
 * See the LICENSE file for the full text.
 * ============================================================================ */

/* Hand-written (NOT vendored) lwIP network-interface glue for the
 * NUCLEO-F767ZI's on-board LAN8742A PHY, over RMII. Synthesized from
 * two ST reference examples, neither copied verbatim (see
 * ../../../../.claude/plans -- or just: the project's own commit
 * history around this file):
 *
 *   - The NO_SYS/standalone polling structure (blocking
 *     HAL_ETH_Transmit, no RTOS, ethernetif_input() called directly
 *     each tick rather than from a semaphore-fed thread) comes from
 *     STM32CubeF7's Projects/STM32756G_EVAL/.../LwIP_UDP_Echo_Server
 *     -- but that example targets a different PHY (DP83848) over MII,
 *     on a different board.
 *   - The RMII pin table and LAN8742A PHY usage come from
 *     STM32CubeF7's Projects/STM32F767ZI-Nucleo/.../
 *     LwIP_HTTP_Server_Netconn_RTOS -- written for exactly this board
 *     and PHY, but FreeRTOS-based (wrong concurrency model here).
 *
 * This project's Telemetry_Sink task (an Ada Ravenscar task, not a
 * FreeRTOS thread -- see ../../behavioral/src/bifrost-telemetry.adb)
 * drives bifrost_ethernetif_poll() once per period, standing in for
 * either reference's own main loop.
 */

#include "stm32f7xx_hal.h"
#include "lan8742.h"
#include "bifrost_net_config.h"

#include "lwip/init.h"
#include "lwip/netif.h"
#include "lwip/timeouts.h"
#include "lwip/pbuf.h"
#include "netif/ethernet.h"
#include "netif/etharp.h"

#include <string.h>
#include <stddef.h>

#define IFNAME0 'b'
#define IFNAME1 'f'

#define ETH_DMA_TRANSMIT_TIMEOUT 20U

/* Must be strictly greater than ETH_RX_DESC_CNT (vendor/hal_f7's own
 * documented constraint on its zero-copy Rx pool sizing) -- 4 Rx
 * descriptors (stm32f7xx_hal_eth.h's default ETH_RX_DESC_CNT), so 6
 * buffers with margin. */
#define ETH_RX_BUFFER_CNT 6U

typedef enum
{
    RX_ALLOC_OK = 0x00,
    RX_ALLOC_ERROR = 0x01
} RxAllocStatusTypeDef;

typedef struct
{
    struct pbuf_custom pbuf_custom;
    uint8_t buff[(ETH_RX_BUF_SIZE + 31) & ~31];
} RxBuff_t;

/* Descriptors and the Rx buffer pool, bundled into one struct so
 * they're laid out contiguously by ordinary C struct rules, then
 * aligned as a whole to 16KB (power-of-two, as ARMv7-M's MPU
 * requires): this gives one block whose *actual link-time address*
 * (read at runtime below, in bifrost_eth_mpu_config) the MPU can mark
 * Non-Cacheable, without needing a custom linker script or a
 * hand-picked fixed address -- the compiler/linker's own alignment
 * directive guarantees the placement is MPU-legal wherever it lands.
 * This is the real fix for the Cortex-M7 D-cache/Ethernet-DMA
 * coherency hazard the project's own network.txt notes and
 * STM32CubeF7's own reference main.c (MPU_Config) both flag --
 * without copying either reference's own fixed addresses, which
 * belong to different, unrelated boards/chips (see ../../../HARDWARE.md). */
typedef struct
{
    ETH_DMADescTypeDef RxDesc[ETH_RX_DESC_CNT];
    ETH_DMADescTypeDef TxDesc[ETH_TX_DESC_CNT];
    RxBuff_t RxBuf[ETH_RX_BUFFER_CNT];
} Bifrost_Eth_Dma_Region_t;

static Bifrost_Eth_Dma_Region_t eth_dma_region __attribute__((aligned(16384)));

LWIP_MEMPOOL_DECLARE(RX_POOL, ETH_RX_BUFFER_CNT, sizeof(RxBuff_t), "Bifrost zero-copy RX pbuf pool");

static uint8_t RxAllocStatus;

static struct netif gnetif;

static ETH_HandleTypeDef EthHandle;
static ETH_TxPacketConfigTypeDef TxConfig;
static lan8742_Object_t LAN8742;

static int32_t ETH_PHY_IO_Init(void);
static int32_t ETH_PHY_IO_DeInit(void);
static int32_t ETH_PHY_IO_ReadReg(uint32_t DevAddr, uint32_t RegAddr, uint32_t *pRegVal);
static int32_t ETH_PHY_IO_WriteReg(uint32_t DevAddr, uint32_t RegAddr, uint32_t RegVal);
static int32_t ETH_PHY_IO_GetTick(void);

static lan8742_IOCtx_t LAN8742_IOCtx = {
    ETH_PHY_IO_Init, ETH_PHY_IO_DeInit, ETH_PHY_IO_WriteReg, ETH_PHY_IO_ReadReg, ETH_PHY_IO_GetTick};

/* Exported from Ada -- see ../lowlevel/src/bifrost-net-eth.adb's own
 * comment on why this project's single time base lives there, not in
 * a (deliberately uncompiled) vendor/hal_f7/Src/stm32f7xx_hal.c. */
extern uint32_t HAL_GetTick(void);

/* vendor/hal_f7/Src/stm32f7xx_hal_rcc.c's HAL_RCC_GetHCLKFreq() (used
 * by HAL_ETH_SetMDIOClockRange to pick the MDC divider) just returns
 * this CMSIS global directly -- normally maintained by
 * system_stm32f7xx.c's SystemInit()/SystemCoreClockUpdate(), neither
 * of which this project calls (the Ada runtime's own start-rom.S +
 * Setup_Pll already brought up clocks -- see Decision 3 in the
 * feature's own design notes). Set here to the *measured* effective
 * clock, not the configured/theoretical one: this board's clock tree
 * has a real, still-unexplained ~1/3 undershoot (confirmed two
 * independent ways on real hardware -- see ../../../KNOWN_ISSUES.md
 * item 4), the same reason ../../lowlevel/src/bifrost-uart.adb's BRR
 * targets ~16.667MHz instead of the theoretical 50MHz PCLK1. HCLK's
 * own theoretical target is 200MHz; divided by the same measured
 * factor of 3, that's ~66.67MHz. MDIO is a slow management bus (a few
 * MHz max) with a generous tolerance, so an imprecise HCLK estimate
 * here is not a data-path risk the way it would be for something
 * timing-critical -- but if the real root cause of the 1/3 undershoot
 * is ever found and fixed upstream, this needs revisiting right
 * alongside the BRR value it's named after. */
uint32_t SystemCoreClock = 66666667U;

/* This runtime links with -nolibc (confirmed directly: no newlib, no
 * rand()) -- lwIP's cc.h LWIP_RAND() macro needs *some* rand()
 * regardless. Nothing in this UDP-only, fixed-local-port
 * configuration actually depends on the quality of this randomness
 * (no TCP sequence numbers -- LWIP_TCP=0; no ephemeral port
 * allocation -- Our_Port comes from net.conf, not lwIP's picker); a
 * small xorshift generator is a self-contained, good-enough source
 * for the few places lwIP calls LWIP_RAND() (e.g. IP identification),
 * not a security-sensitive use. */
int rand(void)
{
    static uint32_t state;

    if (state == 0)
    {
        state = HAL_GetTick() | 1U; /* never 0 -- a 0 seed sticks at 0 forever */
    }
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return (int)(state & 0x7FFFFFFFU);
}

/*******************************************************************************
 * MPU -- carve out the DMA descriptor/buffer region as Non-Cacheable.
 *******************************************************************************/
static void bifrost_eth_mpu_config(void)
{
    MPU_Region_InitTypeDef MPU_InitStruct = {0};

    HAL_MPU_Disable();

    MPU_InitStruct.Enable = MPU_REGION_ENABLE;
    MPU_InitStruct.BaseAddress = (uint32_t)&eth_dma_region;
    MPU_InitStruct.Size = MPU_REGION_SIZE_16KB;
    MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
    MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
    MPU_InitStruct.IsCacheable = MPU_ACCESS_NOT_CACHEABLE;
    MPU_InitStruct.IsShareable = MPU_ACCESS_SHAREABLE;
    MPU_InitStruct.Number = MPU_REGION_NUMBER0;
    MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
    MPU_InitStruct.SubRegionDisable = 0x00;
    MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_DISABLE;
    HAL_MPU_ConfigRegion(&MPU_InitStruct);

    /* MPU_DEFAULT_MAP: everything outside configured regions keeps its
     * normal (cacheable, where applicable) attributes -- this project
     * is not attempting a from-scratch full memory map the way
     * STM32CubeF7's own MPU_Config examples do (those also cover
     * external SDRAM/FMC regions this board doesn't even have); only
     * the one region that actually needs an exception from the
     * runtime's own default gets one. */
    HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
}

/*******************************************************************************
 *                       LL Driver Interface (lwIP --> ETH)
 *******************************************************************************/
static void low_level_init(struct netif *netif)
{
    uint32_t duplex, speed = 0;
    int32_t PHYLinkState;
    ETH_MACConfigTypeDef MACConf = {0};
    static uint8_t macaddress[6] = {
        BIFROST_NET_OUR_MAC0, BIFROST_NET_OUR_MAC1, BIFROST_NET_OUR_MAC2,
        BIFROST_NET_OUR_MAC3, BIFROST_NET_OUR_MAC4, BIFROST_NET_OUR_MAC5};

    EthHandle.Instance = ETH;
    EthHandle.Init.MACAddr = macaddress;
    EthHandle.Init.MediaInterface = HAL_ETH_RMII_MODE;
    EthHandle.Init.RxDesc = eth_dma_region.RxDesc;
    EthHandle.Init.TxDesc = eth_dma_region.TxDesc;
    EthHandle.Init.RxBuffLen = ETH_RX_BUF_SIZE;

    HAL_ETH_Init(&EthHandle);

    netif->hwaddr_len = ETH_HWADDR_LEN;
    memcpy(netif->hwaddr, macaddress, ETH_HWADDR_LEN);
    netif->mtu = ETH_MAX_PAYLOAD;
    netif->flags |= NETIF_FLAG_BROADCAST | NETIF_FLAG_ETHARP;

    LWIP_MEMPOOL_INIT(RX_POOL);

    memset(&TxConfig, 0, sizeof(ETH_TxPacketConfigTypeDef));
    TxConfig.Attributes = ETH_TX_PACKETS_FEATURES_CSUM | ETH_TX_PACKETS_FEATURES_CRCPAD;
    TxConfig.ChecksumCtrl = ETH_CHECKSUM_IPHDR_PAYLOAD_INSERT_PHDR_CALC;
    TxConfig.CRCPadCtrl = ETH_CRC_PAD_INSERT;

    LAN8742_RegisterBusIO(&LAN8742, &LAN8742_IOCtx);

    if (LAN8742_Init(&LAN8742) != LAN8742_STATUS_OK)
    {
        netif_set_link_down(netif);
        netif_set_down(netif);
        return;
    }

    PHYLinkState = LAN8742_GetLinkState(&LAN8742);

    if (PHYLinkState <= LAN8742_STATUS_LINK_DOWN)
    {
        /* No cable plugged in (or no link partner) -- not an error,
         * same as either reference example's own handling. Revisit
         * from TinyMon/console if link-up needs to be user-visible. */
        netif_set_link_down(netif);
        netif_set_down(netif);
        return;
    }

    switch (PHYLinkState)
    {
    case LAN8742_STATUS_100MBITS_FULLDUPLEX:
        duplex = ETH_FULLDUPLEX_MODE;
        speed = ETH_SPEED_100M;
        break;
    case LAN8742_STATUS_100MBITS_HALFDUPLEX:
        duplex = ETH_HALFDUPLEX_MODE;
        speed = ETH_SPEED_100M;
        break;
    case LAN8742_STATUS_10MBITS_FULLDUPLEX:
        duplex = ETH_FULLDUPLEX_MODE;
        speed = ETH_SPEED_10M;
        break;
    case LAN8742_STATUS_10MBITS_HALFDUPLEX:
        duplex = ETH_HALFDUPLEX_MODE;
        speed = ETH_SPEED_10M;
        break;
    default:
        duplex = ETH_FULLDUPLEX_MODE;
        speed = ETH_SPEED_100M;
        break;
    }

    HAL_ETH_GetMACConfig(&EthHandle, &MACConf);
    MACConf.DuplexMode = duplex;
    MACConf.Speed = speed;
    HAL_ETH_SetMACConfig(&EthHandle, &MACConf);

    /* HAL_ETH_Start(), not _Start_IT() -- polling model, matching the
     * NO_SYS reference's own choice; no ETH NVIC line is enabled in
     * bifrost_eth_hal_msp_init() below, deliberately. */
    HAL_ETH_Start(&EthHandle);
    netif_set_up(netif);
    netif_set_link_up(netif);
}

static err_t low_level_output(struct netif *netif, struct pbuf *p)
{
    uint32_t i = 0;
    struct pbuf *q;
    err_t errval = ERR_OK;
    ETH_BufferTypeDef Txbuffer[ETH_TX_DESC_CNT];

    (void)netif;
    memset(Txbuffer, 0, ETH_TX_DESC_CNT * sizeof(ETH_BufferTypeDef));

    for (q = p; q != NULL; q = q->next)
    {
        if (i >= ETH_TX_DESC_CNT)
        {
            return ERR_IF;
        }
        Txbuffer[i].buffer = q->payload;
        Txbuffer[i].len = q->len;
        if (i > 0)
        {
            Txbuffer[i - 1].next = &Txbuffer[i];
        }
        if (q->next == NULL)
        {
            Txbuffer[i].next = NULL;
        }
        i++;
    }

    TxConfig.Length = p->tot_len;
    TxConfig.TxBuffer = Txbuffer;
    TxConfig.pData = p;

    /* Blocking transmit -- simpler and correct for a periodic,
     * low-rate telemetry sender; the interrupt-driven _IT variant
     * (and the TxPktSemaphore plumbing it needs) is the FreeRTOS
     * reference's own concurrency concern, not applicable under
     * NO_SYS. */
    if (HAL_ETH_Transmit(&EthHandle, &TxConfig, ETH_DMA_TRANSMIT_TIMEOUT) != HAL_OK)
    {
        errval = ERR_IF;
    }

    return errval;
}

static struct pbuf *low_level_input(struct netif *netif)
{
    struct pbuf *p = NULL;

    (void)netif;
    if (RxAllocStatus == RX_ALLOC_OK)
    {
        HAL_ETH_ReadData(&EthHandle, (void **)&p);
    }
    return p;
}

static void ethernetif_input(struct netif *netif)
{
    struct pbuf *p;

    do
    {
        p = low_level_input(netif);
        if (p != NULL)
        {
            if (netif->input(p, netif) != ERR_OK)
            {
                pbuf_free(p);
            }
        }
    } while (p != NULL);
}

static err_t ethernetif_init(struct netif *netif)
{
    LWIP_ASSERT("netif != NULL", (netif != NULL));

    netif->name[0] = IFNAME0;
    netif->name[1] = IFNAME1;
    netif->output = etharp_output;
    netif->linkoutput = low_level_output;

    low_level_init(netif);

    return ERR_OK;
}

void pbuf_free_custom(struct pbuf *p)
{
    struct pbuf_custom *custom_pbuf = (struct pbuf_custom *)p;

    LWIP_MEMPOOL_FREE(RX_POOL, custom_pbuf);
    if (RxAllocStatus == RX_ALLOC_ERROR)
    {
        RxAllocStatus = RX_ALLOC_OK;
    }
}

/* lwIP's own NO_SYS=1 time source. */
u32_t sys_now(void)
{
    return HAL_GetTick();
}

/*******************************************************************************
 *                       Ethernet MSP Routines
 *******************************************************************************/
void HAL_ETH_MspInit(ETH_HandleTypeDef *heth)
{
    GPIO_InitTypeDef GPIO_InitStructure = {0};

    (void)heth;

    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_GPIOC_CLK_ENABLE();
    __HAL_RCC_GPIOG_CLK_ENABLE();

    /* RMII pin mapping for NUCLEO-F767ZI, confirmed three independent
     * ways (UM1974 Table 11, the project's own networkstack/network.txt
     * notes, and ST's own board-specific reference ethernetif.c for
     * this exact board) -- see ../../../HARDWARE.md:
     *   REF_CLK=PA1  MDIO=PA2  MDC=PC1   CRS_DV=PA7
     *   RXD0=PC4     RXD1=PC5  TX_EN=PG11
     *   TXD0=PG13    TXD1=PB13
     * (TXD1=PB13, not PG14 -- an earlier general-knowledge guess this
     * project's own research corrected against the real board manual.) */
    GPIO_InitStructure.Speed = GPIO_SPEED_FREQ_HIGH;
    GPIO_InitStructure.Mode = GPIO_MODE_AF_PP;
    GPIO_InitStructure.Pull = GPIO_NOPULL;
    GPIO_InitStructure.Alternate = GPIO_AF11_ETH;

    GPIO_InitStructure.Pin = GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_7;
    HAL_GPIO_Init(GPIOA, &GPIO_InitStructure);

    GPIO_InitStructure.Pin = GPIO_PIN_13;
    HAL_GPIO_Init(GPIOB, &GPIO_InitStructure);

    GPIO_InitStructure.Pin = GPIO_PIN_1 | GPIO_PIN_4 | GPIO_PIN_5;
    HAL_GPIO_Init(GPIOC, &GPIO_InitStructure);

    GPIO_InitStructure.Pin = GPIO_PIN_11 | GPIO_PIN_13;
    HAL_GPIO_Init(GPIOG, &GPIO_InitStructure);

    /* No HAL_NVIC_EnableIRQ(ETH_IRQn) here, deliberately -- polling
     * model (HAL_ETH_Start(), not _Start_IT()), matching the NO_SYS
     * reference's own choice; this project never calls HAL_ETH's
     * interrupt-driven entry points. */

    __HAL_RCC_ETH_CLK_ENABLE();
}

/*******************************************************************************
 *                       PHY IO Functions
 *******************************************************************************/
static int32_t ETH_PHY_IO_Init(void)
{
    HAL_ETH_SetMDIOClockRange(&EthHandle);
    return 0;
}

static int32_t ETH_PHY_IO_DeInit(void)
{
    return 0;
}

static int32_t ETH_PHY_IO_ReadReg(uint32_t DevAddr, uint32_t RegAddr, uint32_t *pRegVal)
{
    return (HAL_ETH_ReadPHYRegister(&EthHandle, DevAddr, RegAddr, pRegVal) == HAL_OK) ? 0 : -1;
}

static int32_t ETH_PHY_IO_WriteReg(uint32_t DevAddr, uint32_t RegAddr, uint32_t RegVal)
{
    return (HAL_ETH_WritePHYRegister(&EthHandle, DevAddr, RegAddr, RegVal) == HAL_OK) ? 0 : -1;
}

static int32_t ETH_PHY_IO_GetTick(void)
{
    return (int32_t)HAL_GetTick();
}

void HAL_ETH_RxAllocateCallback(uint8_t **buff)
{
    struct pbuf_custom *p = (struct pbuf_custom *)LWIP_MEMPOOL_ALLOC(RX_POOL);

    if (p)
    {
        *buff = (uint8_t *)p + offsetof(RxBuff_t, buff);
        p->custom_free_function = pbuf_free_custom;
        pbuf_alloced_custom(PBUF_RAW, 0, PBUF_REF, p, *buff, ETH_RX_BUF_SIZE);
    }
    else
    {
        RxAllocStatus = RX_ALLOC_ERROR;
        *buff = NULL;
    }
}

void HAL_ETH_RxLinkCallback(void **pStart, void **pEnd, uint8_t *buff, uint16_t Length)
{
    struct pbuf **ppStart = (struct pbuf **)pStart;
    struct pbuf **ppEnd = (struct pbuf **)pEnd;
    struct pbuf *p;

    p = (struct pbuf *)(buff - offsetof(RxBuff_t, buff));
    p->next = NULL;
    p->tot_len = 0;
    p->len = Length;

    if (!*ppStart)
    {
        *ppStart = p;
    }
    else
    {
        (*ppEnd)->next = p;
    }
    *ppEnd = p;

    for (p = *ppStart; p != NULL; p = p->next)
    {
        p->tot_len += Length;
    }
}

void HAL_ETH_TxFreeCallback(uint32_t *buff)
{
    pbuf_free((struct pbuf *)buff);
}

/*******************************************************************************
 *                       Ada entry points
 *******************************************************************************/

/* Netmask/gateway are not part of net.conf's five keys (destination
 * IP/port, our IP/port, our MAC) -- the feature's own requirement is
 * a non-routable peer on the *same* segment, which needs neither a
 * real gateway nor a netmask narrower than this default to work.
 * Revisit (add a net.conf key) if a real need for something other
 * than a /24 ever appears -- not preemptively. */
void bifrost_ethernetif_init(void)
{
    ip4_addr_t ipaddr, netmask, gw;

    bifrost_eth_mpu_config();

    lwip_init();

    IP4_ADDR(&ipaddr, BIFROST_NET_OUR_IP0, BIFROST_NET_OUR_IP1, BIFROST_NET_OUR_IP2, BIFROST_NET_OUR_IP3);
    IP4_ADDR(&netmask, 255, 255, 255, 0);
    IP4_ADDR(&gw, 0, 0, 0, 0);

    netif_add(&gnetif, &ipaddr, &netmask, &gw, NULL, &ethernetif_init, &ethernet_input);
    netif_set_default(&gnetif);
}

/* Re-checks PHY link state every tick. Needed because low_level_init()
 * above only checks link state once, at boot: if the LAN8742A hadn't
 * finished autonegotiating with the link partner yet at that exact
 * moment (a few hundred ms to a couple seconds is normal), the
 * interface would otherwise stay marked down forever, even once the
 * link genuinely comes up moments later -- confirmed as a real,
 * reproduced bug on actual hardware (the link came up fine per the
 * host side, HAL_ETH_Start() was simply never called because nothing
 * ever re-checked after the first, too-early look). ST's own
 * FreeRTOS reference example handles this with a periodic
 * ethernet_link_check_state() call from a dedicated thread; this is
 * the same logic, called from here instead since there's no RTOS
 * thread to run it on. */
static void bifrost_eth_link_poll(void)
{
    ETH_MACConfigTypeDef MACConf = {0};
    int32_t PHYLinkState = LAN8742_GetLinkState(&LAN8742);
    uint32_t speed = 0, duplex = 0;

    if (netif_is_link_up(&gnetif) && (PHYLinkState <= LAN8742_STATUS_LINK_DOWN))
    {
        HAL_ETH_Stop(&EthHandle);
        netif_set_down(&gnetif);
        netif_set_link_down(&gnetif);
        return;
    }

    if (netif_is_link_up(&gnetif) || (PHYLinkState <= LAN8742_STATUS_LINK_DOWN))
    {
        return; /* already up, or still down -- nothing changed */
    }

    switch (PHYLinkState)
    {
    case LAN8742_STATUS_100MBITS_FULLDUPLEX:
        duplex = ETH_FULLDUPLEX_MODE;
        speed = ETH_SPEED_100M;
        break;
    case LAN8742_STATUS_100MBITS_HALFDUPLEX:
        duplex = ETH_HALFDUPLEX_MODE;
        speed = ETH_SPEED_100M;
        break;
    case LAN8742_STATUS_10MBITS_FULLDUPLEX:
        duplex = ETH_FULLDUPLEX_MODE;
        speed = ETH_SPEED_10M;
        break;
    case LAN8742_STATUS_10MBITS_HALFDUPLEX:
        duplex = ETH_HALFDUPLEX_MODE;
        speed = ETH_SPEED_10M;
        break;
    default:
        return; /* AUTONEGO_NOTDONE or a read/write error -- try again next tick */
    }

    HAL_ETH_GetMACConfig(&EthHandle, &MACConf);
    MACConf.DuplexMode = duplex;
    MACConf.Speed = speed;
    HAL_ETH_SetMACConfig(&EthHandle, &MACConf);
    HAL_ETH_Start(&EthHandle);
    netif_set_up(&gnetif);
    netif_set_link_up(&gnetif);
}

void bifrost_ethernetif_poll(void)
{
    bifrost_eth_link_poll();
    ethernetif_input(&gnetif);
    sys_check_timeouts();
}

/*******************************************************************************
 *                       Diagnostics (TinyMon "net" command)
 *******************************************************************************/

/* Raw MDIO read of PHY link/speed/duplex state -- one of the
 * LAN8742_STATUS_* values from lan8742.h (negative = a read/write/
 * address/reset error talking to the PHY over MDIO itself, distinct
 * from LAN8742_STATUS_LINK_DOWN which means MDIO is fine but no link
 * partner is present). */
int32_t bifrost_eth_phy_link_state(void)
{
    return LAN8742_GetLinkState(&LAN8742);
}

/* The software's own belief about interface state, as lwIP's netif
 * tracks it -- compare against bifrost_eth_phy_link_state() above to
 * tell a "PHY is fine, software hasn't noticed" bug apart from an
 * actual PHY/MDIO problem. */
int bifrost_eth_netif_is_up(void)
{
    return netif_is_up(&gnetif) ? 1 : 0;
}

int bifrost_eth_netif_is_link_up(void)
{
    return netif_is_link_up(&gnetif) ? 1 : 0;
}

/* Real MAC hardware counter (RM0410's MMCTGFCR, "number of good
 * frames transmitted") -- free-running, increments as a direct side
 * effect of the MAC actually pushing a frame out, with no software
 * layer in between. Added specifically to bisect "the MAC genuinely
 * transmitted, something external (cable/PHY-to-NIC) is wrong" from
 * "the MAC never actually fired despite HAL_ETH_Transmit() returning
 * HAL_OK" -- lwIP's own udp_send()/HAL's own return codes only
 * confirm the DMA descriptor was handed over, not that a frame
 * physically left the PHY. */
uint32_t bifrost_eth_mmc_tx_good_frames(void)
{
    return EthHandle.Instance->MMCTGFCR;
}
