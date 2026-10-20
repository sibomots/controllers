#ifndef __CONTROLLER_RTBUS_H__
#define __CONTROLLER_RTBUS_H__

#include <crc.h>
#include <rtpacket.h>
#include <cmd_handler.h>
#include <crc_16.h>
#include <stdint.h>
#include <string.h>

void rtbus_set_frame_sync(RTMessage_t *const pframe);
void rtbus_initiate_hdr(RTMessage_t *const pframe, const uint8_t pid,
                        const uint8_t pver, const uint8_t remote_terminal_id, const uint8_t response);
void rtbus_preamble(RTMessage_t *const pframe, const uint16_t cmd_id,
                    const uint16_t target_id, const uint16_t instance_id, const uint16_t num_args);
void rtbus_update_payload_size(RTMessage_t *const pframe);
void rtbus_update_header_crc(RTMessage_t *const pframe);
uint16_t rtbus_get_param_count(RTMessage_t *const pframe);
void rtbus_update_payload_crc(RTMessage_t *const pframe);
void rtbus_append_parameter(RTMessage_t *const pframe, const uint16_t idx, const uint32_t arg);
uint8_t verify_frame_sync(const RTMessage_t *const ppacket);
uint8_t verify_rt_address(const RTMessage_t *const ppacket);
uint8_t verify_header_crc(const RTMessage_t *const ppacket);
uint8_t verify_target_id(const RTMessage_t *const ppacket);
uint8_t verify_instance_id(const RTMessage_t *const ppacket);
uint8_t verify_payload_crc(const RTMessage_t *const ppacket);
uint8_t validate_rt_message(uint8_t *const pbuffer);
void construct_rt_message(uint8_t *const pbuffer, const uint16_t fsync, const uint8_t pid, const uint8_t pver, const uint8_t rt_id,
                         const uint16_t cmd_id, const uint16_t tgt_id, const uint16_t inst_id, const uint16_t num_args, const uint32_t *const args);
#else
extern uint8_t validate_rt_message(uint8_t *const pbuffer);
extern void construct_rt_message(uint8_t *const pbuffer, const uint16_t fsync, const uint8_t pid, const uint8_t pver, const uint8_t rt_id,
                                const uint16_t cmd_id, const uint16_t tgt_id, const uint16_t inst_id, const uint16_t num_args, const uint32_t *const args);
#endif
