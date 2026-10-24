#include <tinymon.h>

struct usart_async_descriptor EDBG_COM;
static uint8_t EDBG_COM_buffer[EDBG_COM_BUFFER_SIZE];

static struct io_descriptor *io;
static uint8_t tm_input;
static int tm_idx;
static uint8_t tm_buffer[TM_BUF_SIZ];
static uint8_t tm_status_str[TM_STAT_STR_SIZ];
static uint8_t tm_packet_str[TM_CMD_PKT_STR_SIZ];
static uint8_t tm_cmd_packet[MEMSIZE];
static ParseState_t tm_cmd_state[] = { STANDBY, STANDBY, STANDBY };

static const uint8_t cmda_str[] = "cmda";
static const uint8_t cmdb_str[] = "cmdb";
static const uint8_t cmdc_str[] = "cmdc";

static const uint8_t evaluate_command_str[] = "EVALUATE_COMMAND";
static const uint8_t evaluate_args_str[] = "EVALUATE_ARGS";
static const uint8_t create_packet_str[] = "CREATE_PACKET";
static const uint8_t validate_packet_str[] = "VALIDATE_PACKET";
static const uint8_t done_str[] = "DONE";
static const uint8_t fail_str[] = "FAIL";
static const uint8_t standby_str[] = "STANDBY";

static const uint8_t tm_prompt[] = "\r\nTinyMon> ";
static const int tm_prompt_sz = sizeof(tm_prompt) - 1;

#define TM_PLATFORM_DESC "SAMV71 Xplained Ultra (ATSAMV71Q21B)"

/* Hand-edit this on each release. Deliberately not derived from the
 * git commit SHA -- a build can't know the SHA of the commit that will
 * contain it, and a plain string avoids that chicken-and-egg problem
 * entirely. */
#define TM_SOFTWARE_VERSION "0.1.0"

#define TM_LICENSE_TEXT \
    "Copyright (c) 2025 Jeff Wandling. All rights reserved. | BSD 3-Clause License"

static const uint8_t tm_help_dialogue[] = "\r\n\n" TM_PLATFORM_DESC "\r\n"
                                          "Version " TM_SOFTWARE_VERSION "\r\n"
                                          TM_LICENSE_TEXT "\r\n\n"
                                          "Enter one of the following "
                                          "commands and its parameters:\r\ncmda\r\ncmdb led_id (0 <= led_id <= 1)"
                                          "\r\ncmdc led_id (0 <= led_id <= 1)\r\nlicense\r\n\ni.e. cmdb 1\r\n";

static const uint8_t tm_license_reply[] = "\r\n" TM_LICENSE_TEXT "\r\n";
static const int tm_license_reply_sz = sizeof(tm_license_reply) - 1;

static const uint8_t tm_bs_sequence[] = { BS, SP, BS };
static const uint8_t tm_sp_sequence[] = { SP };
static const uint8_t tm_crlf_sequence[] = { CR, LF };

static const int tm_bs_sequence_sz = 3;
static const int tm_sp_sequence_sz = 1;

static uint8_t tm_help_flag = 0;
static uint8_t tm_license_flag = 0;
static uint8_t tm_print_flag = 0;
static uint8_t tm_success_flag = 0;

static uint8_t tm_welcome[] = "\r\n\r\n"
"This is TinyMon\r\n"
TM_PLATFORM_DESC "\r\n"
"Version " TM_SOFTWARE_VERSION "\r\n"
TM_LICENSE_TEXT "\r\n\r\n"
"Type 'help' for more information.\r\n"
"\r\n";

static const int tm_welcome_sz = sizeof(tm_welcome) - 1;


void usart_tx_cb(const struct usart_async_descriptor* const descr)
{
}
void usart_rx_cb(const struct usart_async_descriptor* const descr)
{
    io_read(io, &tm_input, 1);
}


static uint8_t nibble_to_ascii(const uint8_t num)
{
    if (num >= 0 && num <= 9)
        return (num + '0');
    else if (num >= 0xA && num <= 0xF)
        return (num + 'A' - 0xA);
    else
        return 0;
}

static void hex_to_ascii(uint32_t packet_addr, uint8_t* paddr_string)
{
    if (paddr_string == NULL)
        return;
    uint32_t remainder;

    paddr_string[0] = '0';
    paddr_string[1] = 'x';

    for (int i = ADRR_STR_SIZE - 1; i >= 2; i--)
    {
        remainder = packet_addr % 16;
        paddr_string[i] = nibble_to_ascii(remainder);
        packet_addr = packet_addr / 16;
    }
}

static void build_cmd_packet_str(uint8_t* tm_cmd_packet, uint8_t* str)
{

    if (str == NULL || tm_cmd_packet == NULL)
        return;
    if (tm_success_flag == 0)
        return;

    uint8_t byte_counter = 0;
    uint8_t num_rows = 0;
    RTMessage_t * ppacket = (RTMessage_t *)tm_cmd_packet;
    uint8_t num_args_lsb = ppacket->rtpayload_preamble.arg_count_lsb;
    uint8_t num_args_msb = ppacket->rtpayload_preamble.arg_count_msb;
    uint16_t num_args = num_args_lsb + (((uint16_t)num_args_msb) << 8);
    int packet_size = sizeof(RTMessage_t) + 4 + (4 * num_args);

    while (byte_counter < packet_size)
    {
        if (byte_counter % 16 == 0)
        {
            *str = '\r';
            str++;
            *str = '\n';
            str++;

            uint32_t packet_addr = ((uint32_t)((tm_cmd_packet) + (16 * num_rows)));
            uint8_t addr_string[ADRR_STR_SIZE];
            hex_to_ascii(packet_addr, addr_string);

            for (int i = 0; i < sizeof(addr_string); i++)
            {
                *str = addr_string[i];
                str++;
            }

            *str = ':';
            str++;
            *str = ' ';
            str++;
            num_rows++;
        }

        *str = nibble_to_ascii((tm_cmd_packet[byte_counter] >> 4) & 0xF);
        str++;
        *str = nibble_to_ascii(tm_cmd_packet[byte_counter] & 0xF);
        str++;
        *str = ' ';
        str++;
        byte_counter++;
    }

    *str = '\n';
    str++;
    *str = '\0';
}

static void build_cmd_status_str(const ParseState_t *tm_cmd_state, uint8_t *str)
{

    if (str == NULL || tm_cmd_state == NULL)
        return;
    *str++ = '\n';
    *str++ = '\r';

    uint8_t *cmd_str = (uint8_t*)NULL;
    uint8_t *status_str = (uint8_t*)NULL;

    for (int i = 0; i < NUM_CMDS; i++)
    {
        switch (i)
        {
        case CMDA:
            cmd_str = (uint8_t*)cmda_str;
            break;
        case CMDB:
            cmd_str = (uint8_t*)cmdb_str;
            break;
        case CMDC:
            cmd_str = (uint8_t*)cmdc_str;
            break;
        default:
            cmd_str = (uint8_t*)NULL;
            break;
        }

        if (cmd_str == (uint8_t*)NULL)
        {
            return;
        }

        while (*cmd_str != '\0')
        {
            *str++ = *cmd_str++;
        }

        *str++ = ':';
        *str++ = ' ';

        switch (tm_cmd_state[i])
        {
        case EVALUATE_COMMAND:
            status_str = (uint8_t*)evaluate_command_str;
            break;
        case EVALUATE_ARGS:
            status_str = (uint8_t*)evaluate_args_str;
            break;
        case CREATE_PACKET:
            status_str = (uint8_t*)create_packet_str;
            break;
        case VALIDATE_PACKET:
            status_str = (uint8_t*)validate_packet_str;
            break;
        case DONE:
            status_str = (uint8_t*)done_str;
            break;
        case FAIL:
            status_str = (uint8_t*)fail_str;
            break;
        case STANDBY:
            status_str = (uint8_t*)standby_str;
            break;
        default:
            status_str = (uint8_t*)NULL;
            break;
        }

        if (status_str == (uint8_t*)NULL)
        {
            return;
        }

        while (*status_str != '\0')
        {
            *str = *status_str;
            str++;
            status_str++;
        }

        *str++ = '\n';
        *str++ = '\r';
    }

    *str = '\0';
}

void Print(const uint8_t *pdata, const int len)
{
    if (pdata == NULL)
        return;
    for (int i = 0; i < len; i++)
    {
        while (io_write(io, &pdata[i], 1) != 1)
            ;
    }
}

static void clear_buffer()
{
    tm_input = 0;
    tm_idx = 0;

    for (int i = 0; i < TM_BUF_SIZ; i++)
    {
        tm_buffer[i] = NUL;
    }
    for (int i = 0; i < TM_STAT_STR_SIZ; i++)
    {
        tm_status_str[i] = NUL;
    }
    for (int i = 0; i < TM_CMD_PKT_STR_SIZ; i++)
    {
        tm_packet_str[i] = NUL;
    }
}

static void dispatch_cmd()
{
    if (my_strcmp("help", (const char *)tm_buffer) || my_strcmp("h", (const char *)tm_buffer))
    {
        tm_help_flag = 1;
    }
    else if (my_strcmp("license", (const char *)tm_buffer))
    {
        tm_license_flag = 1;
    }
    else
    {
        for (int i = 0; i < NUM_CMDS; i++)
        {
            tm_cmd_state[i] = STANDBY;
        }

        memset(&tm_cmd_packet[0], 0, MEMSIZE);
        tm_success_flag = handle_command(&tm_buffer[0], &tm_cmd_state[0], &tm_cmd_packet[0]);
        tm_print_flag = 1;
    }
}

static void show_prompt()
{
    Print(tm_prompt, tm_prompt_sz);
}


static void show_welcome()
{
    Print(tm_welcome, tm_welcome_sz);
}

static void parse(void)
{
    if (tm_idx > TM_BUF_SIZ)
    {
        return;
    }

    switch (tm_input)
    {
    case BS:
    case DEL:
        if (tm_idx > 0)
        {
            Print(tm_bs_sequence, tm_bs_sequence_sz);
            tm_idx -= 1;
            tm_buffer[tm_idx] = NUL;
        }
        break;
    case SP:
        Print(tm_sp_sequence, tm_sp_sequence_sz);
        tm_buffer[tm_idx++] = tm_input;
        break;
    case PERIOD:
        Print(&tm_input, 1);
        tm_buffer[tm_idx++] = tm_input;
        break;
    case CR:
        if (tm_idx > 0)
        {
            dispatch_cmd();
        }
        else
        {
            clear_buffer();
            show_prompt();
        }
        break;
    case UNDERSCORE:
        Print(&tm_input, 1);
        tm_buffer[tm_idx++] = tm_input;
        break;
    default:
        if ((tm_input >= 'a') && (tm_input <= 'z'))
        {
            Print(&tm_input, 1);
            tm_buffer[tm_idx++] = tm_input;
        }
        else if ((tm_input >= 'A') && (tm_input <= 'Z'))
        {
            Print(&tm_input, 1);
            tm_buffer[tm_idx++] = tm_input;
        }
        else if ((tm_input >= '0') && (tm_input <= '9'))
        {
            Print(&tm_input, 1);
            tm_buffer[tm_idx++] = tm_input;
        }
    }
    tm_input = 0;
}


void EDBG_COM_CLOCK_init()
{
    _pmc_enable_periph_clock(ID_USART1);
}

void EDBG_COM_PORT_init()
{
    gpio_set_pin_function(PA21, MUX_PA21A_USART1_RXD1);
    gpio_set_pin_function(PB4, MUX_PB4D_USART1_TXD1);
}

void EDBG_COM_init(void)
{
    EDBG_COM_CLOCK_init();
    EDBG_COM_PORT_init();
    usart_async_init(&EDBG_COM, USART1, EDBG_COM_buffer, EDBG_COM_BUFFER_SIZE, _usart_get_usart_async());
}

void process_user_input()
{
    if (tm_input > 0)
    {
        parse();
    }
}

void setup_console()
{
    EDBG_COM_init();
    usart_async_register_callback(&EDBG_COM, USART_ASYNC_TXC_CB, usart_tx_cb);
    usart_async_register_callback(&EDBG_COM, USART_ASYNC_RXC_CB, usart_rx_cb);
    usart_async_get_io_descriptor(&EDBG_COM, &io);
    usart_async_enable(&EDBG_COM);
    clear_buffer();
    show_welcome();
    show_prompt();
}

void print_user_messages()
{
    if (tm_print_flag)
    {
        Print(tm_crlf_sequence, 2);
        Print(tm_packet_str, sizeof(tm_packet_str) - 1);
        Print(tm_status_str, sizeof(tm_status_str) - 1);
        tm_print_flag = 0;
        clear_buffer();
        show_prompt();
    }
    else if (tm_help_flag)
    {
        Print(tm_help_dialogue, sizeof(tm_help_dialogue) - 1);
        tm_help_flag = 0;
        clear_buffer();
        show_prompt();
    }
    else if (tm_license_flag)
    {
        Print(tm_license_reply, tm_license_reply_sz);
        tm_license_flag = 0;
        clear_buffer();
        show_prompt();
    }
}

void build_user_messages()
{
    if (tm_print_flag)
    {
        build_cmd_status_str(tm_cmd_state, tm_status_str);
        build_cmd_packet_str(tm_cmd_packet, tm_packet_str);
    }
}
