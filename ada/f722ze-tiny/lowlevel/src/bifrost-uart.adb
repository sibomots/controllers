-- ============================================================================
-- This file is part of Bifrost
--
-- Copyright (c) 2025 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

with Interfaces; use Interfaces;
with System;
with Bifrost.Board;

package body Bifrost.UART is

   package Board renames Bifrost.Board;

   -- Register addresses come from Bifrost.Board (board-specific,
   -- segregated there so this driver has no board-specific literals
   -- of its own). USART3 on F7 uses the "new" USART IP (separate
   -- ISR/TDR, not the legacy SR/DR pair from F1-F4), confirmed
   -- against RM0431.

   RCC_AHB1ENR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.RCC_AHB1ENR_Addr);
   RCC_APB1ENR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.RCC_APB1ENR_Addr);

   GPIOD_MODER : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.GPIOD_MODER_Addr);
   GPIOD_AFRH  : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.GPIOD_AFRH_Addr);

   USART3_CR1 : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.USART3_CR1_Addr);
   USART3_BRR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.USART3_BRR_Addr);
   USART3_ISR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.USART3_ISR_Addr);
   USART3_RDR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.USART3_RDR_Addr);
   USART3_TDR : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.USART3_TDR_Addr);

   NVIC_ISER1 : Unsigned_32
     with Volatile, Import,
       Address => System'To_Address (Board.NVIC_ISER1_Addr);

   GPIODEN   : constant Unsigned_32 :=
     Shift_Left (1, Board.GPIODEN_Bit);               -- AHB1ENR bit 3
   USART3EN  : constant Unsigned_32 :=
     Shift_Left (1, Board.USART3EN_Bit);               -- APB1ENR bit 18
   RXNE_BIT  : constant Unsigned_32 := 2#0010_0000#;   -- ISR bit 5
   TXE_BIT   : constant Unsigned_32 := 2#1000_0000#;   -- ISR bit 7
   RE_BIT    : constant Unsigned_32 := 2#0000_0100#;   -- CR1 bit 2
   RXNEIE_BIT : constant Unsigned_32 := 2#0010_0000#;  -- CR1 bit 5
   TXEIE_BIT : constant Unsigned_32 := 2#1000_0000#;   -- CR1 bit 7

   -- NVIC_ISER1 covers IRQ32-63; USART3_IRQn=39 is bit (39-32)=7 there.
   NVIC_USART3_Bit : constant Unsigned_32 :=
     Shift_Left (1, Board.USART3_IRQn - 32);

   -- Lock-free single-producer/single-consumer ring buffers. No
   -- protected object -- see the package spec comment for why none is
   -- available on this board. Safe because each buffer has exactly one
   -- writer and one reader: the TX ring is written only by Put
   -- (foreground) and drained only by Interrupt_Handler (ISR); the RX
   -- ring is written only by Interrupt_Handler and drained only by
   -- Try_Get. Classic "one slot wasted" ring design: empty when
   -- Head = Tail, full when advancing Head would reach Tail -- no
   -- separate Count variable needed, which would itself need
   -- synchronizing between the two sides.
   TX_Ring_Size : constant := 128;
   RX_Ring_Size : constant := 16;

   type TX_Index_T is mod TX_Ring_Size;
   type RX_Index_T is mod RX_Ring_Size;

   TX_Buf  : array (TX_Index_T) of Character with Volatile_Components;
   TX_Head : TX_Index_T := 0 with Volatile; -- written by Put only
   TX_Tail : TX_Index_T := 0 with Volatile; -- written by the ISR only

   RX_Buf  : array (RX_Index_T) of Character with Volatile_Components;
   RX_Head : RX_Index_T := 0 with Volatile; -- written by the ISR only
   RX_Tail : RX_Index_T := 0 with Volatile; -- written by Try_Get only

   procedure Initialize is
   begin
      RCC_AHB1ENR := RCC_AHB1ENR or GPIODEN;
      RCC_APB1ENR := RCC_APB1ENR or USART3EN;

      -- PD8, PD9 to alternate-function mode (binary "10" per pin).
      -- Combined 4-bit field at bits[19:16] (pin9 high nibble bits,
      -- pin8 low nibble bits) = "1010" = 16#A#.
      GPIOD_MODER := (GPIOD_MODER and not 16#000F_0000#) or 16#000A_0000#;

      -- AF7 (USART3) on PD8 (AFRH bits[3:0]) and PD9 (AFRH bits[7:4]).
      GPIOD_AFRH := (GPIOD_AFRH and not 16#0000_00FF#) or 16#0000_0077#;

      -- 115200 baud at the default reset clock (HSI 16 MHz, no PLL --
      -- SystemInit is a no-op). BRR = PCLK1 / Baud = 16_000_000 / 115200.
      USART3_BRR := 139;

      -- UE (bit 0) + TE (bit 3) + RE (bit 2) + RXNEIE (bit 5). TXEIE is
      -- enabled on demand by Put, not here -- nothing to transmit yet.
      USART3_CR1 := 2#0000_1001# or RE_BIT or RXNEIE_BIT;

      -- Enable USART3's NVIC line (IRQn 39, bit 7 of ISER1). Until this
      -- is set, USART3_IRQHandler cannot fire regardless of what's in
      -- the vector table -- matching the reasoning the old polled-only
      -- version's comment already gave for why nothing fired before.
      NVIC_ISER1 := NVIC_ISER1 or NVIC_USART3_Bit;
   end Initialize;

   procedure Put (Item : Character) is
      Next : constant TX_Index_T := TX_Head + 1;
   begin
      while Next = TX_Tail loop
         -- Ring full -- wait for Interrupt_Handler to drain a slot
         -- rather than drop the byte (a longer message than the ring
         -- can hold at once must still arrive intact). TXEIE has to be
         -- enabled for the ISR to run at all; enabling it
         -- unconditionally here also covers the case where this is the
         -- very first byte ever queued. Safe to spin here: nothing
         -- disables interrupts around this call, so Interrupt_Handler
         -- keeps firing and advancing TX_Tail while this loop waits.
         USART3_CR1 := USART3_CR1 or TXEIE_BIT;
      end loop;
      TX_Buf (TX_Head) := Item;
      TX_Head := Next;
      USART3_CR1 := USART3_CR1 or TXEIE_BIT;
   end Put;

   procedure Put_Line (Item : String) is
   begin
      for C of Item loop
         Put (C);
      end loop;
      Put (ASCII.CR);
      Put (ASCII.LF);
   end Put_Line;

   procedure Try_Get (Item : out Character; Got : out Boolean) is
   begin
      if RX_Head = RX_Tail then
         Item := ASCII.NUL;
         Got := False;
         return;
      end if;
      Item := RX_Buf (RX_Tail);
      RX_Tail := RX_Tail + 1;
      Got := True;
   end Try_Get;

   procedure Interrupt_Handler is
   begin
      if (USART3_ISR and RXNE_BIT) /= 0 then
         declare
            C    : constant Character :=
              Character'Val (USART3_RDR and 16#FF#); -- self-clears RXNE
            Next : constant RX_Index_T := RX_Head + 1;
         begin
            if Next /= RX_Tail then
               RX_Buf (RX_Head) := C;
               RX_Head := Next;
            end if; -- else: ring full, drop the byte
         end;
      end if;

      if (USART3_ISR and TXE_BIT) /= 0 then
         if TX_Head /= TX_Tail then
            USART3_TDR := Character'Pos (TX_Buf (TX_Tail));
            TX_Tail := TX_Tail + 1;
         else
            USART3_CR1 := USART3_CR1 and not TXEIE_BIT;
         end if;
      end if;
   end Interrupt_Handler;

end Bifrost.UART;
