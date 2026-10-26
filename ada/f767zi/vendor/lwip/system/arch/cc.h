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
#include <stddef.h>

typedef int sys_prot_t;

#define LWIP_PROVIDE_ERRNO

/* lwIP's own SMEMCPY/MEMCPY exist specifically for copies where the
 * source/dest may not be naturally aligned -- e.g. etharp_input's own
 * comment: ARP header fields sit right after a 14-byte Ethernet
 * header, so they land on a 2-byte, not 4-byte, boundary. The
 * default in lwip/opt.h just maps both to plain memcpy(), which is
 * wrong here: this runtime has no libc at all (-nolibc, confirmed),
 * so GCC inlines a small constant-size memcpy() as a single word
 * load/store -- fine on most C environments (Cortex-M7 tolerates
 * unaligned single-word LDR/STR by default), but this Ada runtime
 * has alignment-trap checking enabled (confirmed directly on real
 * hardware: UsageFault, CFSR UNALIGNED bit set, catching exactly
 * this word-sized access on an odd-aligned ARP field) -- plausibly
 * deliberate on GNAT's part, since it catches a real class of error
 * Ada's own type system would normally prevent. The fix belongs
 * here, not in disabling that trap: a byte-at-a-time copy is safe
 * regardless of alignment or trap configuration, on any target, and
 * is exactly what lwIP's own SMEMCPY/MEMCPY indirection exists to let
 * a platform provide. */
static inline void *bifrost_byte_memcpy(void *dst, const void *src, size_t len)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (len--)
    {
        *d++ = *s++;
    }
    return dst;
}
#define SMEMCPY(dst, src, len) bifrost_byte_memcpy((dst), (src), (len))
#define MEMCPY(dst, src, len)  bifrost_byte_memcpy((dst), (src), (len))

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
