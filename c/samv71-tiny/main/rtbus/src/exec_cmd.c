#include <exec_cmd.h>

static const uint32_t *exec_arr[NUM_CMDS];

void render_pins()
{
    for (int cmd_id = 0; cmd_id < NUM_CMDS; cmd_id++)
    {
        if (exec_arr[cmd_id] != NULL)
        {
            switch (cmd_id)
            {
            case CMDA:
                exec_cmda(exec_arr[cmd_id]);
                break;
            case CMDB:
                exec_cmdb(exec_arr[cmd_id]);
                break;
            case CMDC:
                exec_cmdc(exec_arr[cmd_id]);
                break;
            }

            exec_arr[cmd_id] = NULL;
            break;
        }
    }
}

extern void populate_exec_arr(const uint16_t cmd_id, const uint32_t *cmd_args)
{
    for (int i = 0; i < NUM_CMDS; i++)
    {
        exec_arr[i] = NULL;
    }

    exec_arr[cmd_id] = cmd_args;
}

void exec_cmda(const uint32_t *const args)
{
    if (args == NULL)
        return;
}

void exec_cmdb(const uint32_t *const args)
{
    if (args == NULL)
        return;
    if (*args == 0)
    {
        gpio_set_pin_level(LED0, false);
    }
    else if (*args == 1)
    {
        gpio_set_pin_level(LED1, false);
    }
}

void exec_cmdc(const uint32_t *const args)
{
    if (args == NULL)
        return;
    if (*args == 0)
    {
        gpio_set_pin_level(LED0, true);
    }
    else if (*args == 1)
    {
        gpio_set_pin_level(LED1, true);
    }
}
