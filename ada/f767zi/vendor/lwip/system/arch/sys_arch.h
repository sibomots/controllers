/* lwIP arch port header, NO_SYS=1 variant for this project. ST's own
 * reference sys_arch.h (stm32-mw-lwip's system/arch/sys_arch.h)
 * unconditionally #errors unless NO_SYS==0 and pulls in cmsis_os.h --
 * wrong for us: Telemetry_Sink (an Ada Ravenscar task, not a FreeRTOS
 * thread) drives lwIP's polling loop directly, so NO_SYS=1 is
 * deliberate, not a stand-in. lwIP's own NO_SYS=1 code paths never
 * reference sys_sem_t/sys_mbox_t/sys_thread_t -- this header only
 * needs to exist and be empty for the few unconditional
 * "#include arch/sys_arch.h" lines elsewhere in lwIP to resolve. */
#ifndef __SYS_ARCH_H__
#define __SYS_ARCH_H__

#endif /* __SYS_ARCH_H__ */
