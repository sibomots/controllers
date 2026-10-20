#include <cmd_handler.h>

extern uint8_t validate_rt_message(uint8_t *const pbuffer);
extern void construct_rt_message(uint8_t *const pbuffer, const uint16_t fsync, const uint8_t pid, const uint8_t pver, const uint8_t rt_id,
                                const uint16_t cmd_id, const uint16_t tgt_id, const uint16_t inst_id, const uint16_t num_args, const uint32_t *const args);
extern void populate_exec_arr(const uint16_t cmd_id, const uint32_t *args);

uint8_t get_next_token(uint8_t *const tok, const uint8_t **const str)
{
    if (str == NULL || tok == NULL)
        return 0;
    if (*str == NULL)
        return 0;

    uint8_t tok_len = 0;
    char c = **str;

    while (c != ' ' && c != '\0')
    {
        tok[tok_len] = c;
        tok_len++;
        (*str)++;
        c = **str;
    }

    tok[tok_len] = '\0';

    if (c == ' ')
    {
        (*str)++;
    }
    else if (c == '\0')
    {
        *str = NULL;
    }

    return tok_len;
}

uint8_t my_strcmp(const char *str1, const char *str2)
{
    if (str1 == NULL || str2 == NULL)
        return 0;

    char c1 = *str1;
    char c2 = *str2;

    while (c1 == c2)
    {
        if (c1 == '\0' && c2 == '\0')
            return 1;
        str1++;
        str2++;
        c1 = *str1;
        c2 = *str2;
    }

    return 0;
}

uint16_t get_command_id(const uint8_t *token)
{
    uint16_t cmd_id = CMD_ID_ERRNO;
    if (token == NULL)
        return cmd_id;
    const char *command = (const char *)token;

    if (my_strcmp(command, "cmda"))
    {
        cmd_id = CMDA;
    }
    else if (my_strcmp(command, "cmdb"))
    {
        cmd_id = CMDB;
    }
    else if (my_strcmp(command, "cmdc"))
    {
        cmd_id = CMDC;
    }

    return cmd_id;
}

uint8_t verify_command_id(const uint16_t command_id)
{
    uint8_t result = 0;
    switch (command_id)
    {
    case CMDA:
        result = 1;
        break;
    case CMDB:
        result = 1;
        break;
    case CMDC:
        result = 1;
        break;
    default:
        result = 0;
        break;
    }

    return result;
}

uint8_t verify_cmda(const uint32_t *const pargs, const uint8_t num_args)
{
    if (num_args != NUM_ARGS_CMDA)
        return 0;
    return 1;
}

uint8_t verify_cmdb(const uint32_t *const pargs, const uint8_t num_args)
{
    if (num_args != NUM_ARGS_CMDB || pargs == NULL)
        return 0;
    uint32_t led_id = *pargs;
    if (led_id < LED_ID_LOWER || led_id > LED_ID_UPPER)
        return 0;
    return 1;
}

uint8_t verify_cmdc(const uint32_t *const pargs, const uint8_t num_args)
{
    if (num_args != NUM_ARGS_CMDC || pargs == NULL)
        return 0;
    uint32_t led_id = *pargs;
    if (led_id < LED_ID_LOWER || led_id > LED_ID_UPPER)
        return 0;
    return 1;
}

uint32_t ascii_to_uint32(const uint8_t *const ascii_str, const uint8_t arg_length)
{
    if (ascii_str == NULL)
        return 0;
    uint32_t val = 0;

    for (int i = 0; i < arg_length; i++)
    {
        val *= 10;
        val += (ascii_str[i] - '0');
    }

    return val;
}

uint8_t create_arg_arr(uint32_t *const arg_arr, const uint8_t *pbuff)
{
    uint8_t arg[TOK_SZ];

    if (pbuff == NULL || arg_arr == NULL)
        return 0;

    uint8_t arg_length = get_next_token(arg, &pbuff);
    uint8_t num_args = 0;

    while (arg_length != 0)
    {
        arg_arr[num_args] = ascii_to_uint32(arg, arg_length);
        num_args++;
        arg_length = get_next_token(arg, &pbuff);
    }

    return num_args;
}

uint8_t handle_command(const uint8_t *const pbuffer, ParseState_t *const cmd_state, uint8_t *const pcmd_packet)
{
    if (pcmd_packet == NULL || cmd_state == NULL || pcmd_packet == NULL)
        return 0;

    uint32_t args[ARG_ARR_SZ];
    uint8_t tok[TOK_SZ];

    const uint8_t *pcurr = pbuffer;
    uint16_t cmd_id = CMD_ID_ERRNO;
    uint8_t num_args = 0;
    uint8_t func_success = 0;
    uint8_t done = 0;
    ParseState_t state = EVALUATE_COMMAND;

    while (!done)
    {
        switch (state)
        {
        case EVALUATE_COMMAND:
            get_next_token(tok, &pcurr);
            cmd_id = get_command_id(tok);
            func_success = verify_command_id(cmd_id);
            if (!func_success)
                state = FAIL;
            if (state == FAIL)
                break;
            cmd_state[cmd_id] = state;

            state = EVALUATE_ARGS;
            break;
        case EVALUATE_ARGS:

            cmd_state[cmd_id] = state;
            num_args = create_arg_arr(args, pcurr);

            switch (cmd_id)
            {
            case CMDA:
                func_success = verify_cmda(args, num_args);
                break;
            case CMDB:
                func_success = verify_cmdb(args, num_args);
                break;
            case CMDC:
                func_success = verify_cmdc(args, num_args);
                break;
            default:
                func_success = 0;
                break;
            }

            if (!func_success)
                state = FAIL;
            if (state == FAIL)
                break;

            state = CREATE_PACKET;
            break;
        case CREATE_PACKET:
            cmd_state[cmd_id] = state;
            construct_rt_message(pcmd_packet, 0xAA55, 0x80, 0x01, 0x01, cmd_id, 0x01, 0x01, num_args, args);

            if (pcmd_packet == NULL)
            {
                state = FAIL;
            }
            if (state == FAIL)
                break;

            state = VALIDATE_PACKET;
            break;
        case VALIDATE_PACKET:
            cmd_state[cmd_id] = state;
            func_success = validate_rt_message(pcmd_packet);
            if (!func_success)
                state = FAIL;
            if (state == FAIL)
                break;

            state = DONE;
            break;
        case DONE:
            cmd_state[cmd_id] = state;
            const uint32_t *cmd_args = (const uint32_t *)(pcmd_packet + 2 + sizeof(RTHeader_t) + sizeof(RTPayHeader_t));
            populate_exec_arr(cmd_id, cmd_args);
            done = 1;
            break;
        case FAIL:
            if (cmd_id != CMD_ID_ERRNO)
            {
                cmd_state[cmd_id] = state;
            }
            return 0;
        case STANDBY:
            if (cmd_id != CMD_ID_ERRNO)
            {
                cmd_state[cmd_id] = state;
            }
            state = FAIL;
            break;
        default:
            state = FAIL;
            break;
        }
    }

    return 1;
}
