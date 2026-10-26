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

/* Project-specific HAL config for vendored vendor/hal_f7. Deliberately
 * minimal -- only the modules this project's Ethernet/lwIP glue
 * actually touches are enabled. HAL_FLASH/HAL_PWR/HAL_DMA modules are
 * NOT enabled: this project never calls HAL_Init()/SystemClock_Config()
 * (the Ada runtime's own start-rom.S + Setup_Pll already brought up
 * clocks before any application code runs -- see
 * ../../runtime-overrides/README.md), and STM32F7 Ethernet uses its
 * own built-in DMA engine (ETH_DMA* registers), not the chip's
 * general-purpose DMA1/DMA2 peripheral, so HAL_DMA is not needed
 * either -- confirmed directly: vendor/hal_f7/Src/stm32f7xx_hal_eth.c
 * never includes stm32f7xx_hal_dma.h. */
#ifndef __STM32F7xx_HAL_CONF_H
#define __STM32F7xx_HAL_CONF_H

#ifdef __cplusplus
extern "C" {
#endif

#define HAL_MODULE_ENABLED
#define HAL_RCC_MODULE_ENABLED
#define HAL_GPIO_MODULE_ENABLED
#define HAL_CORTEX_MODULE_ENABLED
#define HAL_ETH_MODULE_ENABLED
/* Header-only -- stm32f7xx_hal_rcc.c's HAL_RCC_ClockConfig() (dead
 * code here: nothing calls it, see Decision 3) references FLASH
 * latency macros unconditionally. Enabling this module pulls in
 * stm32f7xx_hal_flash.h's macro/type definitions only -- its .c is
 * deliberately NOT vendored/compiled, so no FLASH HAL object code
 * exists, just the declarations the dead code needs to compile. */
#define HAL_FLASH_MODULE_ENABLED

/* HSE_VALUE: this board's actual 8MHz HSE (ST-LINK MCO), matching
 * ../../runtime-overrides/gnat_user/s-bbbopa.ads's own corrected
 * constant and ST's own stock conf header for this exact board
 * (Projects/STM32F767ZI-Nucleo/.../Inc/stm32f7xx_hal_conf.h in
 * STM32CubeF7) -- not a guess, cross-confirmed. */
#if !defined(HSE_VALUE)
#define HSE_VALUE 8000000U
#endif
#if !defined(HSE_STARTUP_TIMEOUT)
#define HSE_STARTUP_TIMEOUT 100U
#endif

#if !defined(HSI_VALUE)
#define HSI_VALUE 16000000U
#endif

/* Never used by this project (no LSE crystal, no I2S external clock
 * input wired) -- these exist only because stm32f7xx_hal_rcc.{h,c}
 * reference them unconditionally even for code paths this project
 * never calls. Values copied from ST's own stock conf header for
 * this board, not invented. */
#if !defined(LSE_VALUE)
#define LSE_VALUE 32768U
#endif
#if !defined(LSE_STARTUP_TIMEOUT)
#define LSE_STARTUP_TIMEOUT 5000U
#endif
#if !defined(EXTERNAL_CLOCK_VALUE)
#define EXTERNAL_CLOCK_VALUE 12288000U
#endif

#define VDD_VALUE 3300U
#define TICK_INT_PRIORITY 0x0FU
#define USE_RTOS 0U
#define PREFETCH_ENABLE 0U
#define ART_ACCELERATOR_ENABLE 0U

#define USE_HAL_ETH_REGISTER_CALLBACKS 0U

/* ################## Ethernet peripheral configuration ##################### */
/* MAC address comes from net.conf/bifrost-net-config.ads at Ada link
 * time, not from here -- these ETH_MAC_ADDRx macros exist only
 * because vendor/hal_f7/Src/stm32f7xx_hal_eth.c's reference usage
 * pattern expects them; the actual byte values used at runtime are
 * supplied by the Ada glue when it builds EthHandle.Init.MACAddr, not
 * by these macros -- do not treat these as the real configured MAC. */
#define ETH_MAC_ADDR0 ((uint8_t)0x02)
#define ETH_MAC_ADDR1 ((uint8_t)0x00)
#define ETH_MAC_ADDR2 ((uint8_t)0x00)
#define ETH_MAC_ADDR3 ((uint8_t)0x00)
#define ETH_MAC_ADDR4 ((uint8_t)0x00)
#define ETH_MAC_ADDR5 ((uint8_t)0x01)

#define ETH_RX_BUF_SIZE 1528U
#define ETH_TX_BUF_SIZE 1528U

#define LAN8742A_PHY_ADDRESS 0x00U
#define PHY_RESET_DELAY 0x00000FFFU
#define PHY_CONFIG_DELAY 0x00000FFFU
#define PHY_READ_TO 0x0000FFFFU
#define PHY_WRITE_TO 0x0000FFFFU

#ifdef HAL_RCC_MODULE_ENABLED
#include "stm32f7xx_hal_rcc.h"
#endif

#ifdef HAL_GPIO_MODULE_ENABLED
#include "stm32f7xx_hal_gpio.h"
#endif

#ifdef HAL_CORTEX_MODULE_ENABLED
#include "stm32f7xx_hal_cortex.h"
#endif

#ifdef HAL_ETH_MODULE_ENABLED
#include "stm32f7xx_hal_eth.h"
#endif

#ifdef HAL_FLASH_MODULE_ENABLED
#include "stm32f7xx_hal_flash.h"
#endif

#define assert_param(expr) ((void)0U)

#ifdef __cplusplus
}
#endif

#endif /* __STM32F7xx_HAL_CONF_H */
