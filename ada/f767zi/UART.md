# The `f767zi` UART, in Detail

This document is the UART counterpart to
[`NETWORK_STACK.md`](NETWORK_STACK.md) — the full account of how
`Bifrost.UART` actually moves bytes on and off the wire, rooted in the
real call sequences in `lowlevel/src/bifrost-uart.ad*` and
`behavioral/src/bifrost-tinymon.adb`, structured the same way: a
Concept of Operations, then three tracks (initialization, transmit,
receive), each ending with an explicit account of where control hands
over from one execution context to another.

One difference from `NETWORK_STACK.md` worth stating up front: **there
is no Ada/C boundary anywhere in this subsystem.** `Bifrost.UART`
touches `Interfaces.STM32.USART`'s typed register overlays directly —
an SVD-generated Ada BSP bundled with the `light-tasking-stm32f769disco`
runtime, not a hand-rolled address import, but still literally the
memory-mapped peripheral registers, one Ada record field per hardware
bit-field. Where `NETWORK_STACK.md`'s "hand-over" sections are about
Ada calling into vendored C, this document's are about one Ada
execution context (an ordinary task, running at a task priority)
handing off to another (an interrupt handler, running at Ravenscar's
interrupt-priority ceiling) through a single protected object — a
different kind of boundary, but just as real a one, and just as
important to get right.

---

## Concept of Operations

### What this driver actually is

USART3 on this board is wired to PD8 (TX)/PD9 (RX), which the
NUCLEO-144's own on-board ST-LINK converts to a USB Virtual COM Port —
this is the board's serial console, nothing more exotic. `Bifrost.UART`
(`lowlevel/src/bifrost-uart.adb`) is an interrupt-driven, ring-buffer-
backed byte pipe: a protected object (`Controller`, declared inside
the package body, not the spec) owns a 128-byte TX ring and a 16-byte
RX ring, the real USART3 interrupt handler (`pragma Attach_Handler`),
and two blocking entries, `Put`/`Get`. `Bifrost.TinyMon`'s `UART_Sink`
task is the one and only caller of `Get`, blocking on it in a tight
loop as its entire reason to exist — this is the Ravenscar-tasking
counterpart to `f722ze-tiny`'s hand-rolled, lock-free-ring-buffer
version of the same idea, built instead the way
`Samv71_Tiny.USART1` already is, since this runtime (unlike F722ZE's)
has real Ravenscar tasking available.

### The honest OSI-layer correlation — and where it breaks down

It's tempting to map UART onto the same OSI layers `NETWORK_STACK.md`
uses for Ethernet, but the mapping is much thinner here, and being
precise about *where* it breaks down is the actually useful part of
this document:

- **Layer 1 (physical)** is genuinely, fully present in silicon: start
  bit, 8 data bits, stop bit, baud-rate generation from the `BRR`
  register's fractional divider, the electrical TX/RX lines
  themselves. Nothing about this layer is in question.
- **Layer 2 (data link)** — framing, addressing-within-a-frame, CRC,
  byte-stuffing — **does not exist in USART3's hardware, and does not
  exist in `Bifrost.UART`'s software either.** This is the single
  most important fact in this document. There is no start-of-frame or
  end-of-frame marker, no checksum, no byte-stuffing anywhere in the
  driver. `Bifrost.UART` is a dumb, reliable-within-its-ring-limits
  byte pipe — it has no concept of a "packet" at all. Whatever
  framing exists in this system (treating `ASCII.CR` as "end of
  command line") is imposed a full layer further up, by
  `Bifrost.TinyMon`, as an *application* convention the UART driver
  itself knows nothing about. Compare this directly against the
  Ethernet MAC in `NETWORK_STACK.md`: there, frame delimiting and a
  CRC32 are a **hardware guarantee**, enforced on every frame with no
  software choice in the matter. Here, there is no hardware or driver
  guarantee at all — only an application-level convention that could
  just as easily not exist.
- **Layer 3 (network — addressing on a shared bus)** does not apply,
  full stop, for this instance. USART3 is wired point-to-point to the
  ST-LINK's Virtual COM Port, not a shared multi-drop bus — there is
  only ever one other node. (The STM32 USART peripheral *does* support
  a 9-bit address-mark mode for exactly the RS-485-style multidrop
  scenario where an L3-equivalent would matter; `Bifrost.UART`'s
  `CR1` initialization never enables it. If this were a multidrop
  sensor bus instead of a console, that hardware feature is where an
  address-matching concept would live.)
- **Layer 4 (transport — flow control, reassembly)** is present, but
  only partially, and **asymmetrically** — see Part 2 and Part 3
  below for exactly where and why. There is real backpressure on
  transmit and none at all on receive; this is a deliberate, accepted
  tradeoff for a human-typed console, not an oversight, but it is a
  real asymmetry worth naming precisely rather than waving at "layer
  4, roughly."

### Silicon interdependencies

Two clock-gating writes (`RCC_Periph.AHB1ENR.GPIODEN`,
`RCC_Periph.APB1ENR.USART3EN`) have to happen before anything else
touches either peripheral's registers — an unclocked peripheral's
register contents are not just inert, they're undefined. USART3 sits
on the APB1 bus, clocked by `PCLK1`; this is the same clock domain
whose real, measured frequency turned out to disagree with its
theoretical configuration — see Part 1's worked baud-rate example,
the one genuinely hardware-surprising fact this subsystem's bring-up
uncovered. Unlike the network stack, there is no DMA involved anywhere
in this driver (byte-at-a-time interrupt service only) and no cache-
coherency concern follows from that — the ring buffers are ordinary
Ada arrays inside the protected object, touched only by Ada code
(`Put`/`Get`/`Handler`) running on this same CPU, never by a bus-
mastering peripheral. The one real inter-context hazard here is
concurrency, not coherency: an ordinary task and an interrupt handler
touching the same ring-buffer state, resolved by Ravenscar's priority-
ceiling protocol (see each Part's handover section) rather than a
cache-maintenance call.

---

## Part 1 — UART Initialization (with respect to the silicon)

Root call, from `app/src/main.adb` — the very first thing `Main` does,
before even `Bifrost.Net.Eth.Initialize`:

```
Main
  Bifrost.UART.Initialize   -- <-- this part
  Bifrost.TinyMon.Show_Welcome
  Bifrost.Net.Eth.Initialize
```

`Bifrost.UART.Initialize` (`bifrost-uart.adb`) is five register writes,
no C, no HAL:

**1. Clock gating.**
```ada
RCC_Periph.AHB1ENR.GPIODEN := 1;
RCC_Periph.APB1ENR.USART3EN := 1;
```
Ungates GPIOD's bus clock and USART3's own peripheral clock. This is
the actual silicon fact "magic sand" lives at here: these aren't
configuration conveniences, they're power/clock-domain gates — read or
write any USART3 register before this, and the result is architecturally
undefined.

**2. Pin muxing.**
```ada
GPIOD_Periph.MODER := (... bits[19:16] set to "1010" ...);   -- PD8, PD9 -> Alternate Function
GPIOD_Periph.AFRH   := (... bits[7:0] set to "0111 0111" ...); -- AF7 on both pins
```
PD8/PD9 are general-purpose GPIO pins by default, electrically
indistinguishable from any other GPIO pin on the package, until
software tells the GPIO peripheral's internal multiplexer to instead
route USART3's TX/RX silicon onto them. `AF7` is the specific mux
selector value that means "USART1/2/3" on this family — a different
alternate-function number entirely from the `AF11` the network stack's
RMII pins use on the very same GPIO peripheral type (`NETWORK_STACK.md`
Part 1), underscoring that "alternate function" is a per-pin,
per-peripheral-family lookup, not a universal constant.

**3. Baud-rate generation — the worked "magic sand" example.**
```ada
USART3_Periph.BRR := (DIV_Fraction => 1, DIV_Mantissa => 9, Reserved_16_31 => 0);
```
This is the one place this subsystem's real-hardware bring-up found
something genuinely surprising. The clock tree's own status registers
(`RCC_CR`, `RCC_CFGR`) report everything consistent with a 50MHz
`PCLK1` (`PLLRDY=1`, `HSERDY=1`, `SW/SWS=PLL`, `HPRE=/1`, `PPRE1=/4`
off a 200MHz `SYSCLK`) — but the clock actually reaching this
peripheral measures at very close to **1/3** of that, confirmed two
independent ways on real hardware (the UART only works at a terminal
baud of 38400, not the 115200 a 50MHz-based `BRR` computation targets;
and `Ada.Real_Time`, riding the same clock tree, ticked at 1/3 rate
over a real, stopwatch-timed 30-second interval). The root cause of
the 1/3 factor itself is still open (see `../../KNOWN_ISSUES.md` item
4) — one plausible theory (`HSE_Bypass`, on the premise that an
actively-driven crystal needs bypass mode) was tried and confirmed
*not* to change the result at all. Rather than wait on a root cause,
`BRR` is computed to target the **measured** ~16.667MHz effective
clock directly:

```
USARTDIV  = 16_666_667 / 1_843_200             = 9.0422...
Mantissa  = 9
Fraction  = round(0.0422 * 16)                  = 1
BRR       = (9 << 4) | 1                        = 145

Actual baud produced = 16_666_667 / (16 * 9.0625) = 114_943 Hz
                        (0.22% off the 115200 nominal target — within tolerance)
```

If the clock tree's own root cause is ever found and fixed upstream,
this computation needs to go back to targeting the *true* 50MHz
(`Mantissa=27, Fraction=2, BRR=434`) — the comment in `bifrost-uart.adb`
explicitly warns against carrying the measured-clock value forward
blindly if the upstream behavior ever changes. This is a good worked
example for a course/book precisely because it's small enough to
redo by hand and shows the fractional baud-rate generator's actual
arithmetic, not just the final register value.

**4. Enabling the peripheral.**
```ada
USART3_Periph.CR1 := (UE => 1, TE => 1, RE => 1, RXNEIE => 1, others => <>);
```
`UE` (USART Enable) brings the peripheral's internal clock domain out
of reset; `TE`/`RE` enable the transmitter/receiver shift registers
independently (either could be left off for a simplex link — both are
needed here); `RXNEIE` arms the "receive register not empty" interrupt
**permanently**, for the driver's entire lifetime — contrast with
`TXEIE`, deliberately left at its default (0) here and toggled on
demand by `Put`/`Handler` instead (Part 2). Neither parity (`PCE`) nor
a non-default word length (`M`) is set — `others => <>` takes the
record's own defaults — so this link is plain 8N1, with **no hardware
parity checking at all**: another concrete instance of the "Layer 2
doesn't really exist here" point from Concept of Operations — not even
USART3's own single-bit parity-error detection is in use.

**5. The interrupt itself — not an explicit call.**
There is no manual NVIC register write anywhere in `Initialize`, and
no hand-extended vector table (contrast `f722ze-tiny`'s version of
this same driver, which has to do both, because no Ravenscar runtime
exists for that target). What actually wires USART3's interrupt line
to `Controller.Handler` is the `pragma Attach_Handler` on `Handler`'s
declaration inside the protected object — elaborated at library level,
before `Main`'s own body ever runs, per standard Ravenscar
task/protected-object activation order. GNARL (GNAT's Ravenscar
runtime support library) performs the real NVIC enable/priority
programming as a direct consequence of elaborating that pragma; this
project's code never touches NVIC registers itself, the same reason
`Samv71_Tiny.USART1.Initialize` never does either. (This document
does not trace GNARL's own internals to confirm the exact register
sequence it performs — that would need its own separate investigation
of the runtime's source, not assumed here.)

### Handover summary for Part 1

No Ada/C boundary exists in this subsystem at all — everything above
is Ada touching `Interfaces.STM32.*` register overlays directly. The
handover worth naming is temporal, not linguistic: by the time
`Initialize`'s five statements finish, USART3's interrupt is already
armed and `Controller.Handler` is already live, *before* `Initialize`
itself returns — because the attach happened at library elaboration,
earlier than `Initialize` runs, not as a consequence of it.

---

## Part 2 — Transmit Call Sequence

Root call: any caller of `Bifrost.UART.Put`/`Put_Line` — in this
program, `Bifrost.TinyMon`'s welcome banner, prompt, local keystroke
echo, and command output, all funneling through the same path.

```ada
procedure Put (Item : Character) is
begin
   Controller.Put (Item);
end Put;
```

**`Controller.Put`** (protected entry):
```ada
entry Put (Item : Character) when TX_Count < TX_Ring_Size is
begin
   TX_Ring (TX_Head) := Item;
   TX_Head := TX_Head + 1;        -- wraps automatically: TX_Index is `mod 128`
   TX_Count := TX_Count + 1;
   USART3_Periph.CR1.TXEIE := 1;
end Put;
```

- **The entry barrier is the entire flow-control story for transmit.**
  `when TX_Count < TX_Ring_Size` means: if the 128-byte ring is full,
  the *calling task itself blocks*, queued by the Ravenscar runtime,
  until the barrier re-evaluates true — which only happens once the
  interrupt handler (below) drains at least one byte. This is real
  backpressure, but it's a side effect of Ada's protected-entry
  semantics, not anything USART3's hardware or protocol provides.
- Once admitted, the byte is buffered and `TX_Head`/`TX_Count` updated
  — ordinary array/counter bookkeeping, no hardware touched yet except
  the last line:
- `USART3_Periph.CR1.TXEIE := 1` arms the "transmit data register
  empty" interrupt. This single bit write is the actual trigger: the
  NVIC continuously watches both a peripheral's interrupt-enable bit
  and its status bit in hardware; if `ISR.TXE` happens to already be
  1 (transmitter idle) at the instant this write retires, the
  interrupt becomes pending essentially immediately — nothing in
  software polls for this.

**`Controller.Handler`** (the USART3 ISR, firing asynchronously
whenever hardware raises the interrupt):
```ada
if USART3_Periph.CR1.TXEIE = 1 and USART3_Periph.ISR.TXE = 1 then
   if TX_Count > 0 then
      USART3_Periph.TDR.TDR := TDR_TDR_Field (Character'Pos (TX_Ring (TX_Tail)));
      TX_Tail := TX_Tail + 1;
      TX_Count := TX_Count - 1;
   else
      USART3_Periph.CR1.TXEIE := 0;   -- nothing left; stop asking for TXE
   end if;
end if;
```

- **The write to `TDR` is the literal "magic sand" moment** — the
  single instant a byte leaves Ada's control and enters USART3's own
  hardware shift register. From here, the peripheral autonomously
  serializes it (start bit, 8 data bits LSB-first, stop bit, at the
  `BRR`-programmed rate — roughly 87 microseconds per byte at this
  board's actual ~114,943 baud) onto the PD8 pin with **zero further
  software involvement** for that byte. Writing `TDR` also clears
  `TXE` in hardware automatically — the peripheral itself sets `TXE`
  back to 1 only once the byte has moved out of `TDR` into the
  internal shift register and is ready to accept the next one; the
  handler never clears `TXE` explicitly.
- If the ring is empty, the handler disables `TXEIE` instead of
  writing `TDR` — this is what stops the interrupt from re-firing on
  every idle `TXE` edge once there's nothing left to send; the next
  `Put` call re-arms it.
- This repeats, one hardware interrupt per character, until the ring
  drains to empty.

### Handover summary for Part 2

Still no Ada/C boundary — the handover here is from one Ada execution
context to another: `Put` runs on whatever ordinary task called it
(`UART_Sink`, or `Main` during its one-time banner/prompt output);
`Handler` runs later, asynchronously, at interrupt-priority. What
makes touching the same ring-buffer state from both contexts safe
without an explicit lock is `pragma Interrupt_Priority
(System.Interrupt_Priority'First)` on `Controller` — Ravenscar's
priority-ceiling protocol guarantees `Handler` can never run
concurrently with a `Put`/`Get` call already in progress, because the
protected object's ceiling sits above every task priority that ever
calls into it (`UART_Sink` runs at `System.Priority'Last`, strictly
below any `Interrupt_Priority` value). The hardware interrupt is the
only thing that can ever preempt a call into `Controller`; GNAT's
generated code relies on that priority relationship directly, instead
of a software mutex.

---

## Part 3 — Receive Call Sequence

Root call, `Bifrost.TinyMon`'s `UART_Sink` task — a library-level
task whose entire body is this loop:

```ada
task body UART_Sink is
   C : Character;
begin
   loop
      Bifrost.UART.Get (C);
      Parse (C);
   end loop;
end UART_Sink;
```

**`Controller.Get`** (protected entry):
```ada
entry Get (Item : out Character) when RX_Count > 0 is
begin
   Item := RX_Ring (RX_Tail);
   RX_Tail := RX_Tail + 1;
   RX_Count := RX_Count - 1;
end Get;
```
`UART_Sink` blocks here whenever the 16-byte RX ring is empty — for a
human-typed console, this is almost always, and that's fine: blocking
on `Get` *is* this task's idle state, not a busy-wait burning cycles.

Meanwhile, asynchronously, whenever hardware sets `ISR.RXNE` (a byte
has fully arrived in the receive shift register and moved to `RDR`),
the **same** `Controller.Handler` from Part 2 runs — one shared ISR
services both directions, since USART3 has a single interrupt line
for every enabled source:
```ada
if USART3_Periph.ISR.RXNE = 1 then
   declare
      Incoming : constant Character :=
        Character'Val (Natural (USART3_Periph.RDR.RDR and 16#FF#));
   begin
      if RX_Count < RX_Ring_Size then
         RX_Ring (RX_Head) := Incoming;
         RX_Head := RX_Head + 1;
         RX_Count := RX_Count + 1;
      end if;
      -- else: ring full, byte dropped.
   end;
end if;
```

- **Reading `RDR` is the literal "magic sand" moment in reverse** —
  the instant a received byte leaves hardware and enters software.
  Reading `RDR` **self-clears `RXNE` in hardware** — this read must
  happen unconditionally once `RXNE=1` is observed, or the interrupt
  would simply re-fire forever on the same already-received byte; the
  handler never clears `RXNE` explicitly either, same pattern as
  `TXE` in Part 2.
- If the ring has room, the byte is buffered — this is what makes
  `RX_Count > 0` become true, which is exactly the condition `Get`'s
  barrier is waiting on. (The Ravenscar runtime re-evaluates a blocked
  entry's barrier after *any* operation on the same protected object
  completes, including the interrupt handler's own execution — this
  is how a task blocked on `Get` actually wakes up.)
- **If the ring is full, the byte is silently dropped — and nothing
  anywhere is told.** This is the asymmetry flagged in Concept of
  Operations: there is no RTS/CTS wiring and no XON/XOFF software
  convention to tell the remote sender (the terminal program on the
  other end of the Virtual COM Port) to pause. For one human typing
  one keystroke at a time, 16 bytes of slack is never going to
  overflow. For a fast pasted block of text, or any bulk/automated
  sender, it genuinely could, with no error reported. This is a real,
  accepted engineering tradeoff for a console — it would not be an
  acceptable design for a safety-relevant or bulk-data link.

Once `Get` returns, `UART_Sink` calls **`Parse(C)`**
(`behavioral/src/bifrost-tinymon.adb`) — this is where, and only
where, anything resembling framing exists in this entire system:

```ada
case C is
   when ASCII.BS | ASCII.DEL => ... -- backspace edit, with a visual echo sequence
   when ASCII.CR             => ... -- "end of frame": dispatch the buffered line
   when others                =>
      if alnum then
         Bifrost.UART.Put (C);      -- local echo -- re-enters Part 2
         Buffer (Idx) := C; Idx := Idx + 1;
      end if;                       -- else: silently filtered, not "stuffed"
end case;
```

`ASCII.CR` is this system's one and only end-of-frame marker — chosen
by `Bifrost.TinyMon`, known to nothing below it. There is no
byte-stuffing: non-alnum characters outside `BS`/`DEL`/`CR` are simply
filtered (ignored), not escaped or transformed — a content filter, not
a protocol element. The local echo on every accepted character is a
console-UX convenience (so a terminal emulator shows typed characters
without needing local echo itself), not a protocol acknowledgment of
any kind.

### Handover summary for Part 3

Again, no Ada/C boundary — the handover is temporal: the ISR (running
at Ravenscar's interrupt-priority ceiling, effectively "whenever
hardware says so") and `UART_Sink` (running at an ordinary task
priority, scheduled whenever the runtime gets to it) communicate
purely through `Controller`'s shared ring-buffer state and `Get`'s
entry barrier. The ISR never calls `Parse` directly, and `UART_Sink`
never touches `RDR` directly — each side only ever touches its own
half of `Controller`, the same discipline Part 2 relies on in the
other direction.

---

## Summary: UART vs. MAC/PHY, side by side

| | UART (USART3) | Ethernet MAC/PHY |
|---|---|---|
| L1 (physical) | Fully in hardware: start/stop bits, `BRR`-programmed baud | Fully in hardware: RMII bit timing, PHY-sourced `REF_CLK` |
| L2 (data link: framing/CRC/addressing-within-frame) | **Does not exist**, hardware or driver — `Bifrost.UART` is a dumb byte pipe | Fully in hardware — MAC enforces frame delimiting + CRC32 on every frame, no software choice |
| L3 (network: addressing on a shared medium) | **Not applicable** — dedicated point-to-point link, no shared bus | Real — IPv4 addressing, ARP resolution (`NETWORK_STACK.md` Part 2/3) |
| L4 (transport: flow control / reassembly) | Partial, **asymmetric** — backpressure on TX only (blocking `Put`), none on RX (silent drop on overflow) | Real — UDP, software/hardware checksums (`NETWORK_STACK.md` Part 2) |
| Where "framing" actually lives | One layer above the driver, as an app convention (`Bifrost.TinyMon`'s `CR`-delimited lines) | In the MAC's own silicon, unconditionally |
| DMA / cache coherency concern | None — byte-at-a-time interrupt service, no bus-mastering peripheral involved | Central to `NETWORK_STACK.md`'s whole TX-side bug (see that document's "Lessons") |
| Concurrency hazard, and its resolution | Task vs. ISR sharing one protected object's ring buffers; resolved by Ravenscar's priority-ceiling protocol | Same pattern, same resolution, on the RX descriptor/pool side (`eth_dma_region`) |

The deepest, most teachable point in this whole comparison: both
subsystems hand a byte-stream problem off to real interrupt-driven
hardware, but only one of the two (Ethernet) has a *hardware-enforced*
notion of a frame. UART's "frame" is pure software convention, exactly
one layer above the point where this document's "magic sand" bottoms
out.
