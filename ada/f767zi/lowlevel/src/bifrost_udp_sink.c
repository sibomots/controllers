/* ============================================================================
 * This file is part of Bifrost
 *
 * Copyright (c) 2025 Jeff Wandling
 * All Rights Reserved.
 *
 * Licensed under BSD 3-Clause
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted under the terms of the BSD 3-Clause license.
 * See the LICENSE file for the full text.
 * ============================================================================ */

/* Hand-written (NOT vendored) thin wrapper over lwIP's Raw UDP API,
 * called from Ada -- see
 * ../../behavioral/src/bifrost-telemetry-sinks-udp_unicast.adb's own
 * comment on why this boundary is a small C helper rather than deep
 * Ada bindings onto lwIP's C structs (ip_addr_t, pbuf) directly.
 *
 * One PCB, created and udp_connect'd once on first use (a fixed
 * unicast destination for this project's whole lifetime -- no
 * reconnect/reconfigure path exists, nor is one needed), then
 * udp_send() on every call after that.
 */

#include "lwip/udp.h"
#include "lwip/ip4_addr.h"
#include "bifrost_net_config.h"
#include <string.h>

static struct udp_pcb *s_pcb;
static uint32_t s_sent_ok;
static uint32_t s_sent_fail;

static void ensure_pcb(void)
{
    ip4_addr_t dest;

    if (s_pcb != NULL)
    {
        return;
    }

    s_pcb = udp_new();
    if (s_pcb == NULL)
    {
        return; /* PCB pool exhausted -- nothing to send into; next
                  * call retries (s_pcb stays NULL until it succeeds). */
    }

    if (udp_bind(s_pcb, IP_ADDR_ANY, BIFROST_NET_OUR_PORT) != ERR_OK)
    {
        udp_remove(s_pcb);
        s_pcb = NULL;
        return;
    }

    IP4_ADDR(&dest, BIFROST_NET_DEST_IP0, BIFROST_NET_DEST_IP1,
             BIFROST_NET_DEST_IP2, BIFROST_NET_DEST_IP3);
    udp_connect(s_pcb, &dest, BIFROST_NET_DEST_PORT);
}

/* Called from Ada (Bifrost.Telemetry.Sinks.Udp_Unicast.Publish) with
 * the already-serialized Slate_Of_State bytes -- this function knows
 * nothing about telemetry content, only how to get a byte buffer out
 * the configured unicast destination. */
void bifrost_udp_publish(const uint8_t *data, uint16_t length)
{
    struct pbuf *p;

    ensure_pcb();
    if (s_pcb == NULL)
    {
        s_sent_fail++;
        return;
    }

    p = pbuf_alloc(PBUF_TRANSPORT, length, PBUF_RAM);
    if (p == NULL)
    {
        s_sent_fail++;
        return; /* out of pbufs this tick -- drop, same as any other
                  * best-effort UDP sender; next tick tries again. */
    }

    memcpy(p->payload, data, length);
    if (udp_send(s_pcb, p) == ERR_OK)
    {
        s_sent_ok++;
    }
    else
    {
        /* Previously silently ignored -- a real gap: e.g. ERR_RTE
         * ("no route") when the interface is down fails exactly this
         * way, with nothing anywhere surfacing it. */
        s_sent_fail++;
    }
    pbuf_free(p);
}

/* TinyMon "net" command diagnostics. */
uint32_t bifrost_udp_sent_ok(void)
{
    return s_sent_ok;
}

uint32_t bifrost_udp_sent_fail(void)
{
    return s_sent_fail;
}
