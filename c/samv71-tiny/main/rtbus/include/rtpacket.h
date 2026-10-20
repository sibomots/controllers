#ifndef __CONTROLLER_RTPACKET_H__
#define __CONTROLLER_RTPACKET_H__

#include <stdint.h>
#include <string.h>

#if defined(__GNUC__)
typedef struct __attribute__((packed, aligned(1))) _rthdr
#else
#error Compiler not supported.
#endif
{
    uint8_t protocol_id;
    uint8_t protocol_version;
    uint8_t remote_terminal_id;
    uint8_t response;
    uint8_t payload_size_lsb;
    uint8_t payload_size_msb;
    uint32_t timestamp;
    uint16_t reserved_2;
    uint8_t hdr_crc16_lsb;
    uint8_t hdr_crc16_msb;
} RTHeader_t;

#if defined(__GNUC__)
typedef struct __attribute__((packed, aligned(1))) _rtpayhdr
#else
#error Compiler not supported.
#endif
{
    uint8_t cmd_id_lsb;
    uint8_t cmd_id_msb;
    uint8_t target_id_lsb;
    uint8_t target_id_msb;
    uint8_t instance_id_lsb;
    uint8_t instance_id_msb;
    uint8_t arg_count_lsb;
    uint8_t arg_count_msb;
} RTPayHeader_t;

#if defined(__GNUC__)
typedef struct __attribute__((packed, aligned(1))) _rtmessage
#else
#error Compiler not supported.
#endif
{
    uint8_t frame_sync_lsb;
    uint8_t frame_sync_msb;
    RTHeader_t rthdr;
    RTPayHeader_t rtpayload_preamble;
} RTMessage_t;
#endif
