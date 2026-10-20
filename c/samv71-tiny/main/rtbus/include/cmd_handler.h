#ifndef __CONTROLLER_CMD_HANDLER_H__
#define __CONTROLLER_CMD_HANDLER_H__

#include <rtpacket.h>
#include <stddef.h>
#include <stdint.h>

#define TOK_SZ (256U)
#define ARG_ARR_SZ (16U)
#define CMD_ID_ERRNO (0xFFFFU)

#define NUM_CMDS (3U)

#define NUM_ARGS_CMDA (0U)
#define NUM_ARGS_CMDB (1U)
#define NUM_ARGS_CMDC (1U)

#define LED_ID_LOWER (0U)
#define LED_ID_UPPER (1U)

typedef enum parse_state
{
    EVALUATE_COMMAND,
    EVALUATE_ARGS,
    CREATE_PACKET,
    VALIDATE_PACKET,
    DONE,
    FAIL,
    STANDBY
} ParseState_t;

typedef enum command_id
{
    CMDA,
    CMDB,
    CMDC
} CommandID_t;

uint8_t get_next_token(uint8_t *const tok, const uint8_t **const str);
uint8_t my_strcmp(const char *str1, const char *str2);
uint16_t get_command_id(const uint8_t *token);
uint8_t verify_command_id(const uint16_t command_id);
uint8_t verify_cmda(const uint32_t *const args, const uint8_t num_args);
uint8_t verify_cmdb(const uint32_t *const args, const uint8_t num_args);
uint8_t verify_cmdc(const uint32_t *const args, const uint8_t num_args);
uint32_t ascii_to_uint32(const uint8_t *const ascii_str, const uint8_t arg_length);
uint8_t create_arg_arr(uint32_t *const arg_arr, const uint8_t *pbuff);
uint8_t handle_command(const uint8_t *const pbuffer, ParseState_t *const cmd_state, uint8_t *const pcmd_packet);

#endif
