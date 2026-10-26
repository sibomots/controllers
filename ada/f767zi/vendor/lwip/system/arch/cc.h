/* lwIP arch port header, adapted from ST's stm32-mw-lwip reference
 * port (system/arch/cc.h). One deliberate change from the stock file:
 * LWIP_PLATFORM_ASSERT no longer calls printf(). This project's C
 * sources have no retargeted libc I/O (no _write syscall stub, no
 * semihosting wiring on the C side -- GNAT.IO's own semihosting path
 * is Ada-only and unrelated), so a stock assert-via-printf risks
 * pulling in unresolved newlib syscall stubs at link time for a
 * code path that should be rare/never-hit in practice. An infinite
 * loop is the same "stop here, something is wrong" semantics this
 * project's own C_Error_Handler-style conventions already use
 * elsewhere, without the hidden I/O dependency. */
#ifndef __CC_H__
#define __CC_H__

#include "cpu.h"
#include <stdlib.h>

typedef int sys_prot_t;

#define LWIP_PROVIDE_ERRNO

/* define compiler specific symbols -- GCC only; this project's C
 * sources only ever build with arm-eabi-gcc (the GNAT-FSF toolchain's
 * bundled GCC, matched to the Ada runtime's own ABI -- see
 * ../../../bifrost.gpr's Compiler package). */
#define PACK_STRUCT_BEGIN
#define PACK_STRUCT_STRUCT __attribute__((__packed__))
#define PACK_STRUCT_END
#define PACK_STRUCT_FIELD(x) x

#define LWIP_PLATFORM_ASSERT(x) do { for (;;) {} } while (0)

#define LWIP_RAND() ((u32_t)rand())

#endif /* __CC_H__ */
