#ifndef __TINYMON_H__
#define __TINYMON_H__

#include <atmel_start.h>
#include <samv71q21b.h>
#include <pmc.h>
#include <pio.h>

#include <rtpacket.h>
#include <cmd_handler.h>

#define TM_BUF_SIZ (256U)
#define TM_ARGS_SIZ (16U)
#define TM_STAT_STR_SIZ (512U)
#define TM_CMD_PKT_STR_SIZ (512U)
#define SP (0x20U)
#define BS (0x08U)
#define DEL (0x7FU)
#define NUL (0)
#define PERIOD ('.')
#define UNDERSCORE ('_')
#define CR (13U)
#define LF (10U)

#define EDBG_COM_BUFFER_SIZE (16U)
#define MEMSIZE (1024U)
#define ADRR_STR_SIZE (10U)


extern void process_user_input();
extern void setup_console();
extern void print_user_messages();
extern void build_user_messages();
extern void Print(const uint8_t *pdata, const int len);
#endif
