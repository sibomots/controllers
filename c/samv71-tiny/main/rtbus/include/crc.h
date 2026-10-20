#ifndef CRC_H__
#define CRC_H__

#include <stdint.h>

extern uint32_t Crc32(uint32_t const initialCrc,
                      uint8_t const  bytes[],
                      uint32_t const len);

#endif
