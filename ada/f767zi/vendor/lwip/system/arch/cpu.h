/* lwIP arch port header -- byte order for Cortex-M7 in its default
 * (and this whole project's only-ever-used) little-endian mode.
 * Adapted from ST's stm32-mw-lwip reference port (system/arch/cpu.h),
 * unchanged -- this part needed no NO_SYS-specific adjustment. */
#ifndef __CPU_H__
#define __CPU_H__

#ifndef BYTE_ORDER
#define BYTE_ORDER LITTLE_ENDIAN
#endif

#endif /* __CPU_H__ */
