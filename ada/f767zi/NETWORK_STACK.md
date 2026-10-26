# The `f767zi` Network Stack, in Detail

This document is the full account of how Bifrost's network telemetry
feature actually moves bytes on and off the wire on the NUCLEO-F767ZI
board: the real call sequences, file by file and function by function,
and exactly where Ada hands control to C and back. It exists because
the brief mention of this port's design issues in
[`../SOFTWARE.md`](../SOFTWARE.md) ("How f767zi Differs") is
deliberately short; this is the long version, written after bringing
the feature up on real hardware and finding (and fixing) three genuine
bugs along the way. Every claim below about call sequences is rooted
in reading the actual vendored/hand-written source in this tree, not
reconstructed from a generic lwIP/HAL tutorial — file and line
references are given throughout so they can be checked directly.

Scope: this document covers the `f767zi` tree's Ethernet/lwIP
subsystem only (`lowlevel/src/ethernetif.c`,
`lowlevel/src/bifrost_udp_sink.c`, `lowlevel/src/bifrost-net-eth.ad*`,
`vendor/hal_f7`, `vendor/lan8742`, `vendor/lwip`). It does not re-cover
the UART/LCD subsystems, which are unrelated and already documented in
`../SOFTWARE.md`.

---

## Concept of Operations

### What the prototype stack actually does

This is a **one-way, periodic, best-effort UDP unicast telemetry
sender**, not a general-purpose network node. Once per second,
`Telemetry_Sink` (a Ravenscar task) serializes a snapshot of
`Bifrost.Telemetry.Slate_Of_State` and fires it at a single, fixed
destination (`DEST_IP`/`DEST_PORT` from `net.conf`) over IPv4/UDP. The
board never expects — and nothing in this project currently
processes — a meaningful reply on its own bound port
(`OUR_PORT`/5005). Inbound traffic exists and is genuinely processed
(see Part 3), but almost all of it is incidental: ARP requests/replies
needed to resolve the destination's MAC address, and ordinary
broadcast/multicast noise from whatever else is on the test segment,
which lwIP validates and silently discards. There is no DHCP, no TCP,
no sockets API — `LWIP_DHCP=0`, `LWIP_TCP=0`, `LWIP_NETCONN=0`,
`LWIP_SOCKET=0` in `lowlevel/src/lwipopts.h` — lwIP's Raw API is used
directly, matching this project's existing no-OS-abstraction style.

There is also no RTOS underneath lwIP. `NO_SYS=1` means lwIP expects
*something* to call its input-draining and timeout-servicing functions
on a regular cadence, in place of the tight `while(1)` loop ST's own
NO_SYS reference example uses. In this project that "something" is
`Telemetry_Sink`'s own 1-second periodic tick — the same task that
publishes telemetry also drains the network stack, immediately
beforehand, each time it wakes (see Part 3). This is a deliberate
consequence of this project's Ravenscar architecture, not an
oversight: there is exactly one task touching the network interface,
ever, the same single-owner discipline `Bifrost.LCD_Sink` and
`Bifrost.UART` already apply to their own hardware. One real
consequence worth being explicit about: inbound frames (an ARP reply,
say) sit in the DMA's receive ring for up to a full second before
anything drains them. For a 1Hz telemetry sender this is harmless; it
would not be an acceptable design for anything latency-sensitive.

### The MAC/PHY split, and why it matters

A common imprecision is worth heading off: **the MAC is not a separate
chip on the board — it's integrated into the STM32F767ZI's own
silicon** (the `ETH` peripheral, `EthHandle.Instance = ETH` in
`low_level_init()`). What *is* a separate, physical chip on the
Nucleo-144 board is the **PHY** — a Microchip LAN8742A, a few
millimeters away from the MCU package, connected by two independent
electrical interfaces:

- **RMII** (Reduced Media-Independent Interface) carries the actual
  frame data, 2 bits at a time, clocked by `REF_CLK` (50 MHz) — and
  critically, **the PHY generates this clock, not the MCU**: `REF_CLK`
  is an *input* to the STM32 on PA1, sourced from the LAN8742A's own
  crystal. This board's still-open, separately-documented ~1/3
  clock-tree undershoot (`../../KNOWN_ISSUES.md` item 4, affecting the
  STM32's own HSE/PLL-derived clocks) therefore cannot corrupt RMII
  bit timing directly — RMII's bit clock never passes through the
  STM32's own flawed PLL at all.
- **MDIO** (a 2-wire serial management bus, `MDIO`/`MDC` on PA2/PC1)
  is slow, register-level control-plane traffic: link status, speed,
  duplex, autonegotiation state, PHY reset. This *is* indirectly
  affected by the clock-tree issue, since `HAL_ETH_SetMDIOClockRange`
  picks its divider from `HAL_RCC_GetHCLKFreq()`, which this project
  deliberately hardcodes to the *measured* (not theoretical) HCLK
  (`SystemCoreClock = 66666667U` in `ethernetif.c`) for exactly this
  reason — but MDIO's tolerance is wide enough that an imprecise
  estimate here is a non-issue, unlike it would be for RMII's own bit
  timing.

The full RMII pin table (9 pins across GPIOA/B/C/G, all `AF11`,
confirmed three independent ways against UM1974, the project's own
`../../networkstack/network.txt` notes, and ST's own board-specific
reference `ethernetif.c`) lives in `HAL_ETH_MspInit()` — see Part 1.

### Silicon interdependencies: memory, buffers, interrupts

The MAC peripheral has its own **DMA engine**, a hardware bus-master
independent of the Cortex-M7 CPU core. It reads/writes descriptor
rings and data buffers in SRAM directly over the AHB bus — it does not
execute CPU instructions, and critically, **it does not go through the
CPU's D-cache**. This single fact is the root of the one genuinely
hard bug class this port ran into (see "Lessons," below, and Part 2 in
full): any memory the DMA engine touches must either live outside the
CPU's cache, or have its cache state explicitly managed by software
before/after the DMA touches it. This project uses both strategies, in
different places:

- The descriptor rings and the RX buffer pool
  (`eth_dma_region` — `RxDesc`/`TxDesc`/`RxBuf`, see `ethernetif.c`
  lines 86–95) are placed in a link-time-aligned, 16KB block that an
  MPU region marks **Non-Cacheable** at runtime
  (`bifrost_eth_mpu_config()`). CPU and DMA agree on what's there by
  construction — no explicit cache maintenance call is ever needed for
  this region.
- The TX **payload** buffers (the actual UDP/IP/Ethernet-framed bytes,
  as opposed to the descriptors pointing at them) come from a
  completely different place — lwIP's own general heap
  (`lowlevel/src/lwipopts.h`'s `MEM_SIZE`), ordinary cacheable SRAM.
  This region needed the second strategy: an explicit
  `SCB_CleanDCache_by_Addr()` call, added to `low_level_output()` after
  real hardware testing exposed the gap (Part 2 covers this in full —
  it's the central bug this whole document exists partly to explain).

This project also runs the Ethernet MAC in a **pure polling model**:
`HAL_ETH_MspInit()` deliberately never calls
`HAL_NVIC_EnableIRQ(ETH_IRQn)`, and `low_level_init()`/
`bifrost_eth_link_poll()` call `HAL_ETH_Start()`, not the
interrupt-driven `HAL_ETH_Start_IT()`. There is no Ethernet ISR
anywhere in this program. The MAC's DMA engine still runs
autonomously in the background (filling RX descriptors, draining TX
descriptors) — what's absent is any CPU-side notification mechanism;
software finds out what happened only when `Telemetry_Sink`'s next
tick asks. This mirrors the no-RTOS/`NO_SYS=1` choice above: one
cooperative polling loop (well, periodic task) replacing both an RTOS
thread and an interrupt handler.

Finally, there is exactly **one time authority** in this whole
program: `Ada.Real_Time.Clock`, bridged out to C as `HAL_GetTick()`/
`HAL_Delay()` (`bifrost-net-eth.adb`). `vendor/hal_f7/Src/stm32f7xx_hal.c`
— which would normally own a second, SysTick-driven millisecond
counter — is deliberately excluded from the build entirely
(`bifrost.gpr`'s C `Source_Dirs` list doesn't compile it). Every place
the vendored HAL/lwIP/PHY-driver C code asks "what time is it" or
"wait N milliseconds" (PHY register read/write pacing in
`vendor/lan8742`, lwIP's own `sys_now()`) answers through this single
Ada-owned clock, never a second, independently-drifting one.

---

## Part 1 — MAC/PHY and Network-Stack Initialization

Root call, from `app/src/main.adb`:

```
Main
  Bifrost.UART.Initialize        -- console first, for debug visibility
  Bifrost.TinyMon.Show_Welcome
  Bifrost.Net.Eth.Initialize     -- <-- this part
```

`Bifrost.Net.Eth.Initialize` (`lowlevel/src/bifrost-net-eth.adb`) is a
two-line Ada procedure:

```ada
procedure Initialize is
begin
   C_Ethernetif_Init;
end Initialize;
```

**This is the entire Ada side of initialization.** `C_Ethernetif_Init`
is an `Import, Convention => C` binding to `bifrost_ethernetif_init`
(`ethernetif.c`). Ada crosses into C exactly once here, with **no
arguments and no return value** — it contributes nothing at runtime
beyond the call itself. (The board's own MAC address, IP, netmask, and
destination are not passed across this boundary; they're already C
preprocessor constants — `BIFROST_NET_OUR_MAC0`, etc. — generated at
*build* time by `gen_net_config.sh net.conf` into
`lowlevel/src/bifrost_net_config.h`, which `ethernetif.c` includes
directly.) From this one call onward, everything described below is
pure vendored/hand-written C; Ada has no visibility into any of it.

### `bifrost_ethernetif_init()` (`ethernetif.c`)

```c
void bifrost_ethernetif_init(void)
{
    bifrost_eth_mpu_config();
    lwip_init();
    IP4_ADDR(&ipaddr, ...); IP4_ADDR(&netmask, 255,255,255,0); IP4_ADDR(&gw, 0,0,0,0);
    netif_add(&gnetif, &ipaddr, &netmask, &gw, NULL, &ethernetif_init, &ethernet_input);
    netif_set_default(&gnetif);
}
```

Four steps, in order:

**1. `bifrost_eth_mpu_config()`** (static, `ethernetif.c`) —
`HAL_MPU_Disable()`, configures MPU region 0 over
`&eth_dma_region` (16KB, link-time `__attribute__((aligned(16384)))`)
as `MPU_ACCESS_NOT_CACHEABLE` / `MPU_ACCESS_NOT_BUFFERABLE` /
`MPU_ACCESS_SHAREABLE`, then `HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT)`
— everything *outside* this region keeps the runtime's own default
(cacheable) attributes. This has to happen **before** anything touches
the descriptor rings or RX pool, which is why it's step one.

**2. `lwip_init()`** (vendored, `vendor/lwip/src/core/init.c`) — pure
lwIP housekeeping with zero project-specific content: initializes the
memory manager (`mem_init`), the fixed-size memory pools
(`memp_init`, covering `MEMP_NUM_PBUF`/`MEMP_NUM_UDP_PCB`/
`MEMP_NUM_SYS_TIMEOUT` from `lwipopts.h`), the one-time pbuf/netif/IP/
UDP/ARP subsystem setup. This project calls it once because `NO_SYS=1`
doesn't give lwIP an RTOS startup hook to call it from instead.

**3. `netif_add(&gnetif, &ipaddr, &netmask, &gw, NULL, &ethernetif_init, &ethernet_input)`**
— registers the one network interface this project ever has.
Netmask is always `/24` and gateway is always `0.0.0.0`: `net.conf`'s
five keys (destination IP/port, our IP/port, our MAC) don't include
either, because the feature's actual requirement — a non-routable peer
on the *same* segment — needs neither. The two function-pointer
arguments matter: `&ethernetif_init` is called **synchronously, inside
this `netif_add` call**, as the interface's one-time init callback;
`&ethernet_input` becomes `netif->input`, the function Part 3's RX
path eventually calls into.

   **3a. `ethernetif_init(netif)`** (static, `err_t`-returning,
   `ethernetif.c`) — sets `netif->name`, and the two function pointers
   that matter for Parts 2 and 3:
   `netif->output = etharp_output` (lwIP's own ARP-aware IPv4 output
   dispatcher — Part 2 enters this), `netif->linkoutput =
   low_level_output` (**this project's own function** — Part 2 ends
   here). Then calls `low_level_init(netif)`.

   **3b. `low_level_init(netif)`** (static, `ethernetif.c`) — the real
   hardware bring-up:
   - Populates `EthHandle.Init` (MAC address from the net.conf-derived
     constants, `MediaInterface = HAL_ETH_RMII_MODE`, `RxDesc`/`TxDesc`
     pointing into `eth_dma_region`, `RxBuffLen`).
   - `HAL_ETH_Init(&EthHandle)` (vendored, `vendor/hal_f7/Src/stm32f7xx_hal_eth.c`)
     — this is where the HAL's weak-symbol MSP hook,
     `HAL_ETH_MspInit(heth)`, gets invoked (this project supplies the
     strong definition — see below). `HAL_ETH_Init` also resets and
     configures the MAC's own DMA descriptor rings in place and the
     MAC's filter/config registers.
   - `netif->hwaddr`/`hwaddr_len`/`mtu`/`flags` set from the same
     net.conf-derived MAC and `ETH_MAX_PAYLOAD`.
   - `LWIP_MEMPOOL_INIT(RX_POOL)` — initializes the static RX
     zero-copy pbuf pool. Because `RX_POOL`'s backing memory
     (`RxBuf[ETH_RX_BUFFER_CNT]`) is itself inside `eth_dma_region`
     (declared as a field of the same aligned struct, see
     `ethernetif.c` lines 86–95), it inherits the Non-Cacheable MPU
     attribute from step 1 automatically — no separate region needed
     for it.
   - `TxConfig` populated: `ETH_TX_PACKETS_FEATURES_CRCPAD` /
     `ETH_CRC_PAD_INSERT` only (hardware FCS + short-frame padding —
     always needed, unrelated to IP/UDP checksums). Hardware IP/UDP
     checksum *insertion* is deliberately **not** configured here —
     see "Lessons" below for why it was removed.
   - `LAN8742_RegisterBusIO(&LAN8742, &LAN8742_IOCtx)` — binds the
     vendored, chip-agnostic PHY driver (`vendor/lan8742/lan8742.c`) to
     five small shims (`ETH_PHY_IO_Init/DeInit/ReadReg/WriteReg/GetTick`,
     static in `ethernetif.c`), each a thin call into
     `HAL_ETH_ReadPHYRegister`/`WritePHYRegister`/`SetMDIOClockRange`
     — this is the seam that keeps the third-party PHY driver decoupled
     from this specific MAC's MDIO register interface.
   - `LAN8742_Init(&LAN8742)` — resets the PHY over MDIO and
     (re)starts autonegotiation.
   - `LAN8742_GetLinkState(&LAN8742)` — **one-shot** link read. If the
     link happens to already be up at this exact instant, configures
     MAC duplex/speed (`HAL_ETH_GetMACConfig`/`SetMACConfig`) and calls
     `HAL_ETH_Start()` + `netif_set_up`/`netif_set_link_up`. If not —
     the common case, autonegotiation normally takes a few hundred
     milliseconds to ~2 seconds — the interface is left down, and
     bringing it up is deferred entirely to the periodic poll
     described in Part 3 (`bifrost_eth_link_poll()`). This one-shot
     check being the *only* check was the first real bug this session
     found and fixed; see "Lessons."

**4. `netif_set_default(&gnetif)`** — marks this the default route for
any output call that doesn't specify an interface explicitly (not
otherwise exercised by this single-interface project, but required by
convention).

### `HAL_ETH_MspInit()` (`ethernetif.c`)

Called synchronously from inside `HAL_ETH_Init()` above (HAL's
strong/weak symbol override pattern — this project's definition
replaces the vendored HAL's own empty default). Enables `GPIOA`/`B`/
`C`/`G` clocks, configures all 9 RMII pins (`AF11`, high-speed,
no-pull) per the confirmed pin table —
`REF_CLK=PA1 MDIO=PA2 MDC=PC1 CRS_DV=PA7 RXD0=PC4 RXD1=PC5 TX_EN=PG11
TXD0=PG13 TXD1=PB13` — then `__HAL_RCC_ETH_CLK_ENABLE()`. Deliberately
does **not** call `HAL_NVIC_EnableIRQ(ETH_IRQn)` — the polling-model
decision from "Concept of Operations" above is enforced right here, at
the one place an interrupt-driven design would have enabled it.

### Ada/C handover summary for Part 1

One crossing, `Initialize` → `bifrost_ethernetif_init`, no arguments,
no return value, and no re-entry back into Ada at any point during the
entire bring-up. Every subsequent decision (MPU region, lwIP's
internal state, HAL_ETH register programming, PHY MDIO transactions,
`netif` wiring) happens in C that Ada never inspects. The only
Ada-controlled inputs to the whole sequence are build-time constants
baked into a generated header, not anything passed at run time.

---

## Part 2 — Transmit Call Sequence

Root call, from `behavioral/src/bifrost-telemetry.adb`, once per
`Telemetry_Sink` tick (1 Hz):

```
Telemetry_Sink (task body)
  Bifrost.Net.Eth.Poll                              -- Part 3, drains RX first
  Bifrost.Telemetry.Sinks.Publish_All (Slate)        -- <-- this part
```

`Publish_All` (`behavioral/src/bifrost-telemetry-sinks.adb`, the
static sink registry — no tagged dispatch, deliberately, per this
project's existing risk calculus) calls each registered sink in turn;
currently there is exactly one:

```ada
procedure Publish (Slate : Bifrost.Telemetry.Slate_Of_State) is
   Bytes : constant Bifrost.Net.Types.Byte_Array :=
     Bifrost.Telemetry.Wire_Format.Serialize (Slate);
begin
   C_Udp_Publish (Bytes'Address, Bytes'Length);
end Publish;
```

(`behavioral/src/bifrost-telemetry-sinks-udp_unicast.adb`)

`Bifrost.Telemetry.Wire_Format.Serialize` is pure Ada — it builds the
big-endian wire-format byte array (version/sequence/uptime/ADC
channels/tag) entirely in Ada, with no C involved. **The Ada→C
crossing for the entire transmit path happens at exactly one point:**
`C_Udp_Publish(Bytes'Address, Bytes'Length)`, an `Import, Convention =>
C` binding to `bifrost_udp_publish` (`bifrost_udp_sink.c`).
`Bytes'Address` is a raw `System.Address` pointing at an
Ada-stack-allocated byte array (local to the `Telemetry_Sink` task's
own call frame); `Length` is a plain `Unsigned_16`. No lwIP or HAL type
— no `pbuf`, no `ip4_addr_t` — ever crosses into or out of Ada. This
is the literal design intent stated in `bifrost_udp_sink.c`'s own
header comment: "a small C helper rather than deep Ada bindings onto
lwIP's C structs directly."

### `bifrost_udp_publish()` (`bifrost_udp_sink.c`)

```c
void bifrost_udp_publish(const uint8_t *data, uint16_t length)
{
    ensure_pcb();
    p = pbuf_alloc(PBUF_TRANSPORT, length, PBUF_RAM);
    memcpy(p->payload, data, length);
    udp_send(s_pcb, p);
    pbuf_free(p);
}
```

- **`ensure_pcb()`** — first call only: `udp_new()`, `udp_bind(ANY,
  OUR_PORT)`, `udp_connect(DEST_IP, DEST_PORT)`. One PCB, created once,
  used for the program's entire remaining lifetime — this project has
  no reconnect/reconfigure path and doesn't need one.
- **`pbuf_alloc(PBUF_TRANSPORT, length, PBUF_RAM)`** — allocates a
  pbuf from lwIP's **own general heap** (`vendor/lwip/src/core/mem.c`,
  backed by `lwipopts.h`'s `MEM_SIZE` 4KB static array). This is
  ordinary cacheable SRAM, and critically, **not** inside
  `eth_dma_region` — a completely separate memory region from
  everything Part 1's MPU configuration covers. This is the exact
  region that turned out to need explicit cache maintenance; see
  below.
- **`memcpy(p->payload, data, length)`** — copies the Ada-serialized
  bytes into the pbuf at its current (transport-layer) offset. The
  `PBUF_TRANSPORT` allocation type already reserved header room ahead
  of this offset for the UDP+IP+Ethernet headers about to be
  prepended — standard lwIP convention, not project-specific.
- **`udp_send(s_pcb, p)`** (`vendor/lwip/src/core/udp.c:467`) — from
  here, every function in the call chain is vendored lwIP with zero
  project-specific content, until control reaches back into
  `ethernetif.c`:
  - `udp_send` → `udp_send_chksum` → `udp_sendto_chksum` → ... →
    `udp_sendto_if_src_chksum` (`udp.c` ~line 893) — computes the UDP
    checksum in software (`CHECKSUM_GEN_UDP=1` in `lwipopts.h`) and
    writes the UDP header (source/dest port, length) into the space
    `pbuf_header()` exposes immediately before the payload, then calls
    `ip_output_if_src`.
  - → `ip4_output_if_src` → `ip4_output_if_opt_src`
    (`vendor/lwip/src/core/ipv4/ip4.c`) — writes the IPv4 header
    (version/IHL/DSCP/total length/ID/flags/TTL/protocol/checksum/
    source+dest address) into the space `pbuf_header()` exposes
    further back, computing the IP checksum in software
    (`CHECKSUM_GEN_IP=1`). Calls `netif->output(netif, p, dest)`
    (`ip4.c:1007`) — `netif->output` was set to `etharp_output` back in
    Part 1.
  - → `etharp_output` (`vendor/lwip/src/core/ipv4/etharp.c`) — for a
    destination already resolved in the ARP cache (the steady-state
    case once 192.168.10.8's MAC has been learned), looks it up and
    calls `ethernet_output` directly (`etharp.c:769`). For an
    unresolved destination, calls `etharp_query`, which transmits its
    own separate ARP request frame — through this *same* path,
    recursively — and **queues** this pbuf on the ARP table entry
    (`etharp.c:1058`) to be replayed automatically once a reply arrives
    and `etharp_input` (Part 3) updates that entry.
  - → `ethernet_output` (`vendor/lwip/src/netif/ethernet.c:284-304`) —
    reserves the final 14 bytes via `pbuf_header()` and writes the
    Ethernet header: `ethhdr->type = eth_type_be` (a plain struct
    store) and `ethhdr->dest`/`ethhdr->src` via `SMEMCPY` — the
    project's own byte-safe override (see "Lessons"), necessary
    because this header sits at a 2-byte-misaligned offset from the
    pbuf's allocated start (the Ethernet header's own 14 bytes are not
    a multiple of 4). Calls `netif->linkoutput(netif, p)` —
    `netif->linkoutput` was set to `low_level_output` back in Part 1.
    **This is the last vendored-lwIP function in the chain.**

### `low_level_output()` (`ethernetif.c`) — back in project code

```c
static err_t low_level_output(struct netif *netif, struct pbuf *p)
{
    for (q = p; q != NULL; q = q->next) {
        Txbuffer[i].buffer = q->payload;
        Txbuffer[i].len = q->len;
        SCB_CleanDCache_by_Addr(...);   /* <-- the fix */
        i++;
    }
    TxConfig.Length = p->tot_len;
    TxConfig.TxBuffer = Txbuffer;
    HAL_ETH_Transmit(&EthHandle, &TxConfig, ETH_DMA_TRANSMIT_TIMEOUT);
}
```

- Walks the pbuf chain (in this project's traffic, almost always a
  single segment — one `pbuf_alloc` call, headers prepended in place
  rather than chained as separate pbufs), filling an
  `ETH_BufferTypeDef[]` array with each segment's buffer pointer and
  length.
- **`SCB_CleanDCache_by_Addr()`** (CMSIS, `core_cm7.h`) — for each
  segment, manually aligned down to the 32-byte cache line boundary
  (the CMSIS call does **not** self-align; its own doc comment requires
  a pre-aligned address) and the length extended to cover the full
  aligned span. This flushes whatever the CPU had just written — the
  entire UDP/IP/Ethernet header chain built in the previous dozen
  function calls, moments earlier — out of the D-cache and into
  physical RAM, *before* the DMA engine is told to read that memory.
  Without this call (the state of this code for most of this bring-up
  session), the DMA engine — which bypasses the CPU's cache entirely —
  could read stale/zeroed physical memory for any cache line still
  dirty, while HAL's blocking wait for DMA completion gave no
  indication anything was wrong. See "Lessons" for the full,
  hardware-confirmed failure signature this produced.
- **`HAL_ETH_Transmit()`** (`vendor/hal_f7/Src/stm32f7xx_hal_eth.c`) —
  programs the TX descriptors (`eth_dma_region.TxDesc`, itself
  Non-Cacheable per Part 1, so *this* handoff was always coherent),
  sets the DMA `OWN` bit, and genuinely blocks — spinning on `OWN`
  until the hardware clears it — until the MAC has actually pulled the
  frame across the AHB bus and handed it to the RMII transmit path, or
  times out. On success, the MAC's own `MMCTGFCR` hardware counter
  (a real silicon fact, unrelated to any software belief) increments —
  exposed to Ada as `Mmc_Tx_Good_Frames` for exactly this reason: the
  decisive check for "did the MAC genuinely transmit."
- Back in `bifrost_udp_publish`, `udp_send`'s return value is checked
  (`s_sent_ok`/`s_sent_fail`), and `p` is `pbuf_free()`'d.

### Ada/C handover summary for Part 2

One crossing per telemetry tick, `Publish` → `C_Udp_Publish`,
contributing only a pointer into Ada-owned stack memory and a length —
memory the C side copies out of immediately (`memcpy`) and never
retains a reference to beyond that single call. Every protocol
decision from there (UDP/IP header construction, ARP resolution or
queuing, Ethernet framing, DMA descriptor programming, and — per the
bug this session fixed — the cache-coherency contract between the CPU
and the MAC's DMA engine) is resolved entirely inside vendored lwIP or
this project's own `ethernetif.c`, with zero Ada visibility and zero
re-entry into Ada at any point.

---

## Part 3 — Receive Call Sequence

Root call, same tick as Part 2, immediately before it:

```
Telemetry_Sink (task body)
  Bifrost.Net.Eth.Poll           -- <-- this part
  Bifrost.Telemetry.Sinks.Publish_All (Slate)
```

`Bifrost.Net.Eth.Poll` (`bifrost-net-eth.adb`) is, like `Initialize`,
a single-line Ada wrapper:

```ada
procedure Poll is
begin
   C_Ethernetif_Poll;
end Poll;
```

`C_Ethernetif_Poll` binds to `bifrost_ethernetif_poll`
(`ethernetif.c`) — **the one Ada→C crossing for the entire receive
path**, taking no arguments and returning nothing. Ada has no
visibility into how many frames were drained this tick, what they
contained, or what (if anything) lwIP did with them.

### `bifrost_ethernetif_poll()` (`ethernetif.c`)

```c
void bifrost_ethernetif_poll(void)
{
    bifrost_eth_link_poll();
    ethernetif_input(&gnetif);
    sys_check_timeouts();
}
```

**1. `bifrost_eth_link_poll()`** (static) — re-reads
`LAN8742_GetLinkState(&LAN8742)` over MDIO **every tick**, the fix for
the autonegotiation-race bug Part 1 flagged (the link-state check
`low_level_init()` does is a single, boot-time snapshot; if
autonegotiation hadn't finished at that exact instant, nothing would
ever look again without this). On a down→up transition: configures MAC
duplex/speed and calls `HAL_ETH_Start()` + `netif_set_up`/
`netif_set_link_up`. On an up→down transition (cable pulled):
`HAL_ETH_Stop()` + `netif_set_down`/`netif_set_link_down`. Otherwise a
no-op. This mirrors ST's own FreeRTOS reference example's
`ethernet_link_check_state()`, called from a dedicated thread there —
here, from this same periodic tick instead, since there's no second
thread to run it on.

**2. `ethernetif_input(&gnetif)`** (static) — drains **every** frame
the MAC's DMA has already received and queued since the last tick, not
just one:

```c
do {
    p = low_level_input(netif);
    if (p != NULL) { if (netif->input(p, netif) != ERR_OK) pbuf_free(p); }
} while (p != NULL);
```

- **`low_level_input(netif)`** → `HAL_ETH_ReadData(&EthHandle,
  (void**)&p)` (vendored HAL) — walks the RX descriptor ring
  (`eth_dma_region.RxDesc`, Non-Cacheable per Part 1) for descriptors
  the DMA has marked complete, invoking two callbacks this project
  supplies along the way:
  - **`HAL_ETH_RxAllocateCallback(uint8_t **buff)`** — called whenever
    the HAL needs a fresh buffer to re-arm a freed descriptor: pulls
    one `RxBuff_t` from `RX_POOL` (`LWIP_MEMPOOL_ALLOC`, itself inside
    `eth_dma_region`), wraps it as a **zero-copy** `pbuf_custom`
    (`pbuf_alloced_custom(PBUF_RAW, 0, PBUF_REF, ...)`) — the pbuf's
    payload pointer *is* the DMA's actual destination buffer; there is
    no `memcpy` anywhere in the receive path, unlike the transmit
    path's `bifrost_udp_publish`.
  - **`HAL_ETH_RxLinkCallback(pStart, pEnd, buff, Length)`** — called
    once per descriptor consumed (a frame larger than one buffer spans
    several), linking the `pbuf_custom`s into a chain and setting
    `p->len`/`p->tot_len` from the byte count the descriptor actually
    reports.
  - Because `RX_POOL`'s backing memory is inside the same
    Non-Cacheable MPU region as the descriptors, the CPU is guaranteed
    to see exactly what the DMA engine wrote, with no dirty-cache-line
    window to fall into — **this is why the receive path never needed
    the explicit cache-clean fix the transmit path did**; see
    "Lessons."
- If a pbuf came back, **`netif->input(p, netif)`** — set to
  `&ethernet_input` back in Part 1's `netif_add` call — hands off into
  vendored lwIP:
  - **`ethernet_input(p, netif)`** (`vendor/lwip/src/netif/ethernet.c:81`)
    — reads the 14-byte Ethernet header directly out of `p->payload`
    and dispatches on `ethhdr->type`:
    - **`ETHTYPE_ARP` → `etharp_input(p, netif)`**
      (`vendor/lwip/src/core/ipv4/etharp.c`) — the function that hit
      the *first* real alignment `UsageFault` during this bring-up
      (`IPADDR_WORDALIGNED_COPY_TO_IP4_ADDR_T` → `SMEMCPY`, fixed by
      overriding `SMEMCPY` to a byte-safe copy — see "Lessons").
      Handles both ARP requests (replies to "who-has
      192.168.10.100") and ARP replies (resolves the configured
      destination's MAC, updates `arp_table`, and — closing the loop
      with Part 2 — replays any pbuf that had been queued on that
      exact entry by `etharp_query`).
    - **`ETHTYPE_IP` → `ip4_input(p, netif)`**
      (`vendor/lwip/src/core/ipv4/ip4.c`) — the function that hit the
      *second* alignment `UsageFault`
      (`ip_addr_copy_from_ip4` → a plain, non-overridable struct
      assignment, fixed only by a compiler-level
      `-mno-unaligned-access` flag — see "Lessons"). Validates the IP
      header; in this project's actual traffic, this path mostly
      receives broadcast/multicast chatter from the Windows test host
      that gets validated and silently dropped (no listener on the
      relevant port/protocol) — nothing currently answers the
      telemetry sender back, so this path exists to keep lwIP's own
      internal bookkeeping (and the ARP cache it depends on) correct,
      not to deliver payload upward to the Ada application.
  - On error, `ethernetif_input` itself frees the pbuf; on success,
    lwIP's own input functions free it once finished.

**3. `sys_check_timeouts()`** (`vendor/lwip/src/core/timeouts.c`) —
services every registered lwIP timer; the only one this project's
traffic exercises in practice is ARP's own aging/retry timer
(`etharp_tmr`, which re-transmits through the Part 2 TX path if a
cached entry goes stale).

### Ada/C handover summary for Part 3

One crossing per tick, `Poll` → `bifrost_ethernetif_poll`, no
arguments, no return value, no re-entry into Ada. It is the mirror
image of Part 2: Ada periodically asks C to "do whatever housekeeping
is due," and the entire call graph underneath
(`ethernetif_input` → `netif->input` → `ethernet_input` →
`etharp_input`/`ip4_input` → `sys_check_timeouts`) is self-contained
vendored lwIP plus this project's glue, never touching Ada memory or
calling back into Ada.

---

## Lessons: the three real bugs this port's bring-up found

All three were found only on real hardware — none was predictable from
reading the vendored source or the reference examples alone — and
each is referenced above at the exact call-sequence point it occurs.
Collected here for a single-place summary:

1. **PHY link race (Part 1).** `low_level_init()`'s link check runs
   exactly once, at boot. Autonegotiation normally takes a few hundred
   milliseconds to ~2 seconds; if it hadn't finished at that instant,
   the interface stayed down forever with nothing ever looking again.
   Fixed by `bifrost_eth_link_poll()`, called every `Telemetry_Sink`
   tick (Part 3, step 1).

2. **Two Cortex-M7 alignment `UsageFault`s (Part 3).** This project's
   `-nolibc`, bare-metal Ada runtime has alignment-trap checking
   enabled, and the Ethernet header's 14 bytes (not a multiple of 4)
   shift every field after it to a 2-byte-misaligned offset. GCC
   inlined small, constant-size struct copies as single unsafe word
   loads/stores in two separate spots — `etharp_input`'s
   `IPADDR_WORDALIGNED_COPY_TO_IP4_ADDR_T` (macro-routed through the
   overridable `SMEMCPY`, fixed with a byte-safe override in
   `vendor/lwip/system/arch/cc.h`) and `ip4_input`'s
   `ip_addr_copy_from_ip4` (a plain, non-overridable struct assignment
   macro, fixed instead with a comprehensive `-mno-unaligned-access`
   compiler flag in `bifrost.gpr`, since patching every such site
   individually across the whole vendored tree doesn't scale).

3. **TX-side D-cache/DMA coherency gap (Part 2).** The MPU's
   Non-Cacheable carve-out covered the descriptor rings and the RX
   pool, but not the memory TX pbufs actually live in (lwIP's own
   general heap). `HAL_ETH_Transmit()` blocking on the descriptor's
   `OWN` bit proved the *descriptor* handoff was coherent; it proved
   nothing about whether the CPU's header/payload writes into the
   *payload buffer* had actually left the D-cache before the DMA
   engine — which bypasses cache — read physical RAM. Symptom on the
   wire, confirmed repeatedly via Wireshark: fields written latest
   (destination IP, UDP header, payload) read as stale/zero while
   earlier-written fields (source IP) came through correct; one
   capture even exposed literal leftover bytes from an earlier,
   unrelated ARP transmission still physically sitting in that same
   heap memory. Fixed by adding `SCB_CleanDCache_by_Addr()` over each
   TX buffer segment in `low_level_output()`, immediately before
   `HAL_ETH_Transmit()`.

A hypothesis that looked equally plausible from source reading alone —
that STM32F7 hardware checksum *insertion* was corrupting the same
region — was tried first, rebuilt, reflashed, and **disproved** on real
hardware: the corruption pattern was byte-for-byte identical with
software checksums alone. It's left disabled anyway (software
checksumming costs microseconds for a 1Hz, ~60-byte packet, not worth
re-introducing a once-suspected subsystem for), but it was not,
despite initial appearances, the actual bug. This is the clearest
illustration in this whole bring-up of why every fix in this document
was confirmed by reflashing and re-capturing on real hardware, not
accepted on the strength of the reasoning alone.
