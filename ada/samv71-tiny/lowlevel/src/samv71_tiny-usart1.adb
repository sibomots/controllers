-- ============================================================================
-- This file is part of samv71-tiny
--
-- Copyright (c) 2025 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

-- Depending on Interfaces.SAM/.PIO/.PMC at all triggers GNAT's
-- "internal GNAT unit"/"non-portable and version-dependent" warning --
-- deliberately silenced for this file in samv71_tiny.gpr, not fixed;
-- see that project file's Compiler package comment for the full
-- accepted-risk rationale.

with System;
with Ada.Interrupts.Names;
with Interfaces.SAM;          use Interfaces.SAM;
with Interfaces.SAM.PIO;      use Interfaces.SAM.PIO;
with Interfaces.SAM.PMC;      use Interfaces.SAM.PMC;
with Samv71_Tiny.USART_Regs;  use Samv71_Tiny.USART_Regs;
with Samv71_Tiny.MATRIX_Regs; use Samv71_Tiny.MATRIX_Regs;
with Samv71_Tiny.Board;       use Samv71_Tiny.Board;

package body Samv71_Tiny.USART1 is

   TX_Ring_Size : constant := 128;
   RX_Ring_Size : constant := 16;

   type TX_Index is mod TX_Ring_Size;
   type RX_Index is mod RX_Ring_Size;

   type TX_Buffer is array (TX_Index) of Character;
   type RX_Buffer is array (RX_Index) of Character;

   protected Controller is
      pragma Interrupt_Priority (System.Interrupt_Priority'First);

      entry Put (Item : Character);
      entry Get (Item : out Character);

   private
      procedure Handler;
      pragma Attach_Handler (Handler, Ada.Interrupts.Names.USART1);

      TX_Ring  : TX_Buffer;
      TX_Head  : TX_Index := 0;
      TX_Tail  : TX_Index := 0;
      TX_Count : Natural range 0 .. TX_Ring_Size := 0;

      RX_Ring  : RX_Buffer;
      RX_Head  : RX_Index := 0;
      RX_Tail  : RX_Index := 0;
      RX_Count : Natural range 0 .. RX_Ring_Size := 0;
   end Controller;

   protected body Controller is

      --  TX_IER's write-only "strobe" semantics mean writing TXRDY =>
      --  1 enables it and RXRDY => 0 leaves RXRDY's current enable
      --  state untouched -- this is not a full register overwrite at
      --  the hardware level, even though it reads like one here.
      entry Put (Item : Character) when TX_Count < TX_Ring_Size is
      begin
         TX_Ring (TX_Head) := Item;
         TX_Head := TX_Head + 1;
         TX_Count := TX_Count + 1;
         USART1_Periph.US_IER := (RXRDY => 0, TXRDY => 1, Reserved_2_31 => 0);
      end Put;

      entry Get (Item : out Character) when RX_Count > 0 is
      begin
         Item := RX_Ring (RX_Tail);
         RX_Tail := RX_Tail + 1;
         RX_Count := RX_Count - 1;
      end Get;

      procedure Handler is
      begin
         if USART1_Periph.US_IMR.TXRDY = 1 and USART1_Periph.US_CSR.TXRDY = 1 then
            if TX_Count > 0 then
               USART1_Periph.US_THR.TXCHR :=
                 USART_US_THR_TXCHR_Field (Character'Pos (TX_Ring (TX_Tail)));
               TX_Tail := TX_Tail + 1;
               TX_Count := TX_Count - 1;
            else
               --  Nothing left to send -- stop asking for TXRDY until
               --  the next Put re-enables it, same as usart1.c's ISR.
               USART1_Periph.US_IDR := (RXRDY => 0, TXRDY => 1, Reserved_2_31 => 0);
            end if;
         end if;

         if USART1_Periph.US_CSR.RXRDY = 1 then
            declare
               Incoming : constant Character :=
                 Character'Val (Natural (USART1_Periph.US_RHR.RXCHR));
            begin
               if RX_Count < RX_Ring_Size then
                  RX_Ring (RX_Head) := Incoming;
                  RX_Head := RX_Head + 1;
                  RX_Count := RX_Count + 1;
               end if;
               --  else: ring full, byte dropped -- RHR is read either
               --  way (required to clear RXRDY and avoid re-firing).
            end;
         end if;
      end Handler;

   end Controller;

   procedure Put (Item : Character) is
   begin
      Controller.Put (Item);
   end Put;

   procedure Get (Item : out Character) is
   begin
      Controller.Get (Item);
   end Get;

   procedure Initialize is
      --  USART1's peripheral ID (14) relative to PMC_PCER0.PID's base
      --  position (hardware bit 7 = PID bit 0) -- see
      --  Samv71_Tiny.Board's comment on USART1_Peripheral_ID.
      USART1_Clock_Bit : constant := 2 ** (USART1_Peripheral_ID - 7);
   begin
      PMC_Periph.PMC_PCER0 :=
        (Reserved_0_6 => 0,
         PID          => (As_Array => False, Val => USART1_Clock_Bit));

      --  PA21 = RXD1, peripheral function A (both ABCDSR select bits
      --  cleared), handed over from PIO to the peripheral.
      PIOA_Periph.PIO_ABCDSR (0) :=
        (As_Array => False,
         Val      => PIOA_Periph.PIO_ABCDSR (0).Val and not (2 ** PA21));
      PIOA_Periph.PIO_ABCDSR (1) :=
        (As_Array => False,
         Val      => PIOA_Periph.PIO_ABCDSR (1).Val and not (2 ** PA21));
      PIOA_Periph.PIO_PDR := (As_Array => False, Val => 2 ** PA21);

      --  PB4 = TXD1, peripheral function D (both ABCDSR select bits
      --  set), handed over from PIO to the peripheral, and released
      --  from its JTAG (TDI) default via MATRIX.CCFG_SYSIO.
      PIOB_Periph.PIO_ABCDSR (0) :=
        (As_Array => False,
         Val      => PIOB_Periph.PIO_ABCDSR (0).Val or 2 ** PB4);
      PIOB_Periph.PIO_ABCDSR (1) :=
        (As_Array => False,
         Val      => PIOB_Periph.PIO_ABCDSR (1).Val or 2 ** PB4);
      PIOB_Periph.PIO_PDR := (As_Array => False, Val => 2 ** PB4);
      MATRIX_Periph.CCFG_SYSIO.SYSIO4 := 1;

      --  Reset receiver/transmitter/status, configure 8N1 at 115200
      --  baud (CD/FP for the runtime's native 150MHz Master Clock --
      --  see samv71_tiny-usart1.ads), enable the receive interrupt
      --  permanently (transmit is enabled per-byte by Put/Handler
      --  above), then enable the receiver and transmitter themselves.
      --
      --  No WPMR unlock/lock dance (unlike usart1.c's init sequence):
      --  write protection defaults to disabled at reset and nothing in
      --  this application ever enables it, so there is nothing to
      --  unlock.
      USART1_Periph.US_CR :=
        (Reserved_0_1 => 0, RSTRX => 1, RSTTX => 1, RXEN => 0, RXDIS => 0,
         TXEN => 0, TXDIS => 0, RSTSTA => 1, Reserved_9_31 => 0);
      USART1_Periph.US_MR :=
        (USART_MODE => 0, USCLKS => 0, CHRL => 3, SYNC => 0, PAR => 4,
         NBSTOP => 0, CHMODE => 0, Reserved_16_31 => 0);
      USART1_Periph.US_BRGR := (CD => 81, FP => 3, Reserved_19_31 => 0);
      USART1_Periph.US_IER := (RXRDY => 1, TXRDY => 0, Reserved_2_31 => 0);
      USART1_Periph.US_CR :=
        (Reserved_0_1 => 0, RSTRX => 0, RSTTX => 0, RXEN => 1, RXDIS => 0,
         TXEN => 1, TXDIS => 0, RSTSTA => 0, Reserved_9_31 => 0);
   end Initialize;

end Samv71_Tiny.USART1;
