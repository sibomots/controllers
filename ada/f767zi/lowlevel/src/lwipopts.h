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

/* Project-specific lwIP config for vendor/lwip. Deliberately minimal
 * for a one-way periodic UDP unicast sender: no TCP, no DHCP, no
 * Netconn/Socket API (Raw API only, consistent with this project's
 * existing no-OS-abstraction style -- see
 * ../../behavioral/src/bifrost-telemetry.ads). Based on ST's own
 * reference LwIP_UDP_Echo_Server example's lwipopts.h, trimmed. */
#ifndef __LWIPOPTS_H__
#define __LWIPOPTS_H__

/* NO_SYS==1: no RTOS -- this project's Ravenscar Telemetry_Sink task
 * drives lwIP's polling loop (ethernetif_input + sys_check_timeouts)
 * on its own periodic tick, standing in for the tight while(1) the
 * reference example uses. */
#define NO_SYS 1
#define SYS_LIGHTWEIGHT_PROT 0

/* ---------- Memory options ---------- */
#define MEM_ALIGNMENT 4
/* Small heap -- a periodic fixed-size UDP payload needs far less than
 * the reference's HTTP-server-sized 16KB. Revisit if a real need
 * appears, not preemptively. */
#define MEM_SIZE (4 * 1024)

#define MEMP_NUM_PBUF 8
#define MEMP_NUM_UDP_PCB 2
#define MEMP_NUM_SYS_TIMEOUT 6

/* ---------- Pbuf options ---------- */
#define PBUF_POOL_SIZE 4
#define PBUF_POOL_BUFSIZE 512

/* ---------- IPv4 options ---------- */
#define LWIP_IPV4 1

/* ---------- TCP/ICMP/DHCP options ---------- */
/* No TCP at all -- pure UDP sender, further reduction vs. the
 * reference example's LWIP_TCP=1. */
#define LWIP_TCP 0
/* No DHCP -- static addressing from net.conf (non-routable, same
 * segment as the target board, per the feature's own requirement). */
#define LWIP_DHCP 0
#define LWIP_ICMP 1

/* ---------- UDP options ---------- */
#define LWIP_UDP 1
#define UDP_TTL 255

/* ---------- Statistics / link callback ---------- */
#define LWIP_STATS 0
#define LWIP_NETIF_LINK_CALLBACK 1

/* ---------- Checksum options ---------- */
/* Software checksums, not hardware offload. Originally used hardware
 * offload (same choice the reference example makes) -- reverted after
 * a real hardware session where every captured packet showed the
 * destination IP and the entire UDP header (ports + length) reading
 * as zero, with only the checksum field itself populated -- exactly
 * the region hardware checksum insertion has to read and rewrite, and
 * the only thing that differs between this packet and the
 * byte-for-byte-correct earlier fields. Root cause not conclusively
 * pinned down (would need lower-level register tracing this project
 * doesn't have access to from here), but for a 1Hz, ~60-byte packet
 * the performance cost of software checksumming is microseconds --
 * not a trade-off worth keeping a suspect subsystem for. Revisit
 * hardware offload only if there's a real throughput need later, with
 * a logic analyzer or similar to actually confirm the mechanism
 * first. */
#define CHECKSUM_GEN_IP 1
#define CHECKSUM_GEN_UDP 1
#define CHECKSUM_GEN_TCP 1
#define CHECKSUM_CHECK_IP 1
#define CHECKSUM_CHECK_UDP 1
#define CHECKSUM_CHECK_TCP 1
#define CHECKSUM_GEN_ICMP 1

/* ---------- Sequential layer / socket options ---------- */
/* Raw API only -- no Netconn, no BSD sockets. */
#define LWIP_NETCONN 0
#define LWIP_SOCKET 0

#endif /* __LWIPOPTS_H__ */
