#ifndef __CONTROLLER_EXEC_CMD_H__
#define __CONTROLLER_EXEC_CMD_H__

#include <atmel_start.h>
#include <cmd_handler.h>
#include <stdint.h>

void render_pins();
void populate_exec_arr(const uint16_t cmd_id, const uint32_t *const args);
void exec_cmda(const uint32_t *const args);
void exec_cmdb(const uint32_t *const args);
void exec_cmdc(const uint32_t *const args);
#else
extern void render_pins();
extern void populate_exec_arr(const uint16_t cmd_id, const uint32_t *const args);
#endif
