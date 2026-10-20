#include <crc_16.h>

static uint16_t update_crc16(uint16_t crc, uint8_t c);

uint16_t crc_16(uint8_t* data, uint32_t len)
{
    uint32_t i;
    uint16_t crc = 0x6363;

    for (i = 0; i < len; ++i)
        crc = update_crc16(crc, data[i]);
    return crc;
}

uint16_t update_crc16(uint16_t crc, uint8_t c)
{
    uint16_t i, v, tcrc = 0;

    v = (crc ^ c) & 0xff;
    for (i = 0; i < 8; i++)
    {
        tcrc = ((tcrc ^ v) & 1) ? (tcrc >> 1) ^ 0x8408 : tcrc >> 1;
        v >>= 1;
    }
    return ((crc >> 8) ^ tcrc) & 0xffff;
}
