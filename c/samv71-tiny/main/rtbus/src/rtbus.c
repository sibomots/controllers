#include <rtbus.h>

#define CRC32_START_VAL (0)

void rtbus_set_frame_sync(RTMessage_t *const pframe)
{
    if (pframe == NULL)
        return;
    pframe->frame_sync_lsb = 0x55;
    pframe->frame_sync_msb = 0xAA;
}

void rtbus_initiate_hdr(RTMessage_t *const pframe, const uint8_t pid,
                        const uint8_t pver, const uint8_t remote_terminal_id, const uint8_t response)
{
    if (pframe == NULL)
        return;
    pframe->rthdr.protocol_id = pid;
    pframe->rthdr.protocol_version = pver;
    pframe->rthdr.remote_terminal_id = remote_terminal_id;
    pframe->rthdr.response = response;
    pframe->rthdr.reserved_2 = 0xFFFF;
    pframe->rthdr.payload_size_lsb = 0;
    pframe->rthdr.payload_size_msb = 0;
    pframe->rthdr.timestamp = 0x00000000;
    pframe->rthdr.hdr_crc16_lsb = 0;
    pframe->rthdr.hdr_crc16_msb = 0;
}

void rtbus_preamble(RTMessage_t *const pframe, const uint16_t cmd_id,
                    const uint16_t target_id, const uint16_t instance_id, const uint16_t num_args)
{
    if (pframe == NULL)
        return;
    pframe->rtpayload_preamble.cmd_id_lsb = (cmd_id & 0xFF);
    pframe->rtpayload_preamble.cmd_id_msb = ((cmd_id >> 8) & 0xFF);
    pframe->rtpayload_preamble.target_id_lsb = (target_id & 0xFF);
    pframe->rtpayload_preamble.target_id_msb = ((target_id >> 8) & 0xFF);
    pframe->rtpayload_preamble.instance_id_lsb = (instance_id & 0xFF);
    pframe->rtpayload_preamble.instance_id_msb = ((instance_id >> 8) & 0xFF);
    pframe->rtpayload_preamble.arg_count_lsb = (num_args & 0xFF);
    pframe->rtpayload_preamble.arg_count_msb = ((num_args >> 8) & 0xFF);
}

void rtbus_update_payload_size(RTMessage_t *const pframe)
{
    if (pframe == NULL)
        return;
    uint16_t payload_size = sizeof(RTPayHeader_t);
    uint16_t arg_size = pframe->rtpayload_preamble.arg_count_lsb + (pframe->rtpayload_preamble.arg_count_msb << 8);
    payload_size += (arg_size * 4);
    pframe->rthdr.payload_size_lsb = (payload_size & 0xFF);
    pframe->rthdr.payload_size_msb = ((payload_size >> 8) & 0xFF);
}

void rtbus_update_header_crc(RTMessage_t *const pframe)
{
    if (pframe == NULL)
        return;
    uint16_t header_crc = crc_16(&pframe->rthdr.protocol_id, sizeof(RTHeader_t) - 2);
    pframe->rthdr.hdr_crc16_lsb = (header_crc & 0xFF);
    pframe->rthdr.hdr_crc16_msb = ((header_crc >> 8) & 0xFF);
}

uint16_t rtbus_get_param_count(RTMessage_t *const pframe)
{
    if (pframe == NULL)
        return 0;
    uint16_t n = 0U;
    n = (0xFF & pframe->rtpayload_preamble.arg_count_lsb) |
        (0xFF00 & (pframe->rtpayload_preamble.arg_count_msb << 8));
    return n;
}

void rtbus_update_payload_crc(RTMessage_t *const pframe)
{
    if (pframe == NULL)
        return;
    uint8_t *pPayLoadStart = (uint8_t *)pframe + 2 + sizeof(RTHeader_t);
    unsigned char *paddress_of_parameters = (uint8_t *)pframe + sizeof(RTMessage_t);
    uint32_t *param = (uint32_t *)paddress_of_parameters + pframe->rtpayload_preamble.arg_count_lsb + (((uint16_t)pframe->rtpayload_preamble.arg_count_msb) << 8);
    uint32_t number_of_bytes_to_crc32 = sizeof(RTPayHeader_t) + 4 * (pframe->rtpayload_preamble.arg_count_lsb + (((uint16_t)pframe->rtpayload_preamble.arg_count_msb) << 8));
    uint32_t payload_crc = Crc32(CRC32_START_VAL, pPayLoadStart, number_of_bytes_to_crc32);

    *(uint32_t *)param = payload_crc;
}

void rtbus_append_parameter(RTMessage_t *const pframe, const uint16_t idx, const uint32_t arg)
{
    if (pframe == NULL)
        return;
    uint8_t *pNextArg = (uint8_t *)pframe + 2 + sizeof(RTHeader_t) + sizeof(RTPayHeader_t);
    pNextArg += (sizeof(uint32_t) * idx);
    *(uint32_t *)pNextArg = arg;
}

uint8_t verify_frame_sync(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;

    uint8_t fsync_lsb = ppacket->frame_sync_lsb;
    uint8_t fsync_msb = ppacket->frame_sync_msb;

    if (fsync_lsb == 0x55 && fsync_msb == 0xAA)
        return 1;
    else
        return 0;
}

uint8_t verify_rt_address(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;

    uint8_t rt_addr = ppacket->rthdr.remote_terminal_id;
    switch (rt_addr)
    {
    case 0x00:
        break;
    case 0x01:
        break;
    case 0x02:
        break;
    default:
        return 0;
    }

    return 1;
}

uint8_t verify_header_crc(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;
    uint8_t packet_crc16_lsb = ppacket->rthdr.hdr_crc16_lsb;
    uint8_t packet_crc16_msb = ppacket->rthdr.hdr_crc16_msb;
    uint16_t packet_crc16 = packet_crc16_lsb + (((uint16_t)packet_crc16_msb) << 8);

    uint8_t *start_crc16 = (uint8_t *)(&(ppacket->rthdr));
    uint16_t calculated_crc16 = crc_16(start_crc16, sizeof(RTHeader_t) - 2);

    if (packet_crc16 == calculated_crc16)
    {
        return 1;
    }
    else
        return 0;
}

uint8_t verify_target_id(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;
    uint8_t trgt_id_lsb = ppacket->rtpayload_preamble.target_id_lsb;
    uint8_t trgt_id_msb = ppacket->rtpayload_preamble.target_id_msb;
    uint16_t target_id = trgt_id_lsb + (((uint16_t)trgt_id_msb) << 8);

    switch (target_id)
    {
    case 0x0000:
        break;
    case 0x0001:
        break;
    case 0x0002:
        break;
    default:
        return 0;
    }

    return 1;
}

uint8_t verify_instance_id(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;
    uint8_t inst_id_lsb = ppacket->rtpayload_preamble.instance_id_lsb;
    uint8_t inst_id_msb = ppacket->rtpayload_preamble.instance_id_msb;
    uint16_t instance_id = inst_id_lsb + (((uint16_t)inst_id_msb) << 8);

    switch (instance_id)
    {
    case 0x0000:
        break;
    case 0x0001:
        break;
    case 0x0002:
        break;
    default:
        return 0;
    }

    return 1;
}

uint8_t verify_payload_crc(const RTMessage_t *const ppacket)
{
    if (ppacket == NULL)
        return 0;
    uint8_t payload_size_lsb = ppacket->rthdr.payload_size_lsb;
    uint8_t payload_size_msb = ppacket->rthdr.payload_size_msb;
    uint32_t num_bytes_to_crc32 = payload_size_lsb + (((uint16_t)payload_size_msb) << 8);

    uint8_t *payload_start = (uint8_t *)(&(ppacket->rtpayload_preamble));
    uint32_t packet_crc32 = *((uint32_t *)(payload_start + num_bytes_to_crc32));
    uint32_t calculated_crc32 = Crc32(CRC32_START_VAL, payload_start, num_bytes_to_crc32);

    if (packet_crc32 == calculated_crc32)
    {
        return 1;
    }
    else
        return 0;
}

extern uint8_t validate_rt_message(uint8_t *const pbuffer)
{
    if (pbuffer == NULL)
        return 0;
    uint8_t success = 0;
    const RTMessage_t *const pcandidate_packet = (RTMessage_t *const)pbuffer;

    success = verify_frame_sync(pcandidate_packet);
    if (!success)
        return 0;

    success = verify_rt_address(pcandidate_packet);
    if (!success)
        return 0;

    success = verify_header_crc(pcandidate_packet);
    if (!success)
        return 0;

    uint8_t cmd_id_lsb = pcandidate_packet->rtpayload_preamble.cmd_id_lsb;
    uint8_t cmd_id_msb = pcandidate_packet->rtpayload_preamble.cmd_id_msb;
    uint16_t command_id = cmd_id_lsb + (((uint16_t)cmd_id_msb) << 8);
    success = verify_command_id(command_id);
    if (!success)
        return 0;

    success = verify_target_id(pcandidate_packet);
    if (!success)
        return 0;

    success = verify_instance_id(pcandidate_packet);
    if (!success)
        return 0;

    uint8_t arg_count_lsb = pcandidate_packet->rtpayload_preamble.arg_count_lsb;
    uint8_t arg_count_msb = pcandidate_packet->rtpayload_preamble.arg_count_msb;
    uint16_t argument_count = arg_count_lsb + (((uint16_t)arg_count_msb) << 8);
    const uint32_t *const pargs = (const uint32_t *const)(((const uint8_t *const)(&(pcandidate_packet->rtpayload_preamble))) + sizeof(pcandidate_packet->rtpayload_preamble));

    switch (command_id)
    {
    case CMDA:
        success = verify_cmda(pargs, argument_count);
        break;
    case CMDB:
        success = verify_cmdb(pargs, argument_count);
        break;
    case CMDC:
        success = verify_cmdc(pargs, argument_count);
        break;
    default:
        success = 0;
    }

    if (!success)
        return 0;

    success = verify_payload_crc(pcandidate_packet);
    if (!success)
        return 0;

    return 1;
}

extern void construct_rt_message(uint8_t *const pbuffer, const uint16_t fsync, const uint8_t pid, const uint8_t pver, const uint8_t rt_id,
                                const uint16_t cmd_id, const uint16_t tgt_id, const uint16_t inst_id, const uint16_t num_args, const uint32_t *const args)
{
    if (pbuffer == NULL)
        return;
    RTMessage_t *const pmessage = (RTMessage_t *const)pbuffer;
    pmessage->frame_sync_lsb = (fsync & 0xFF);
    pmessage->frame_sync_msb = ((fsync >> 8) & 0xFF);

    rtbus_initiate_hdr(pmessage, pid, pver, rt_id, 0x00);
    rtbus_preamble(pmessage, cmd_id, tgt_id, inst_id, num_args);
    rtbus_update_payload_size(pmessage);
    rtbus_update_header_crc(pmessage);

    for (uint16_t i = 0; i < rtbus_get_param_count(pmessage); i++)
    {
        rtbus_append_parameter(pmessage, i, args[i]);
    }

    rtbus_update_payload_crc(pmessage);
}
