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

with System;
with Ada.Interrupts.Names;
with Interfaces.STM32;       use Interfaces.STM32;
with Interfaces.STM32.RCC;   use Interfaces.STM32.RCC;
with Interfaces.STM32.GPIO;  use Interfaces.STM32.GPIO;
with Interfaces.STM32.USART; use Interfaces.STM32.USART;
with Bifrost.Board;          use Bifrost.Board;

package body Bifrost.UART is

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
      pragma Attach_Handler (Handler, Ada.Interrupts.Names.USART3_Interrupt);

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

      entry Put (Item : Character) when TX_Count < TX_Ring_Size is
      begin
         TX_Ring (TX_Head) := Item;
         TX_Head := TX_Head + 1;
         TX_Count := TX_Count + 1;
         USART3_Periph.CR1.TXEIE := 1;
      end Put;

      entry Get (Item : out Character) when RX_Count > 0 is
      begin
         Item := RX_Ring (RX_Tail);
         RX_Tail := RX_Tail + 1;
         RX_Count := RX_Count - 1;
      end Get;

      procedure Handler is
      begin
         if USART3_Periph.CR1.TXEIE = 1 and USART3_Periph.ISR.TXE = 1 then
            if TX_Count > 0 then
               USART3_Periph.TDR.TDR :=
                 TDR_TDR_Field (Character'Pos (TX_Ring (TX_Tail)));
               TX_Tail := TX_Tail + 1;
               TX_Count := TX_Count - 1;
            else
               -- Nothing left to send -- stop asking for TXE until the
               -- next Put re-enables it, same as f722ze-tiny's ISR.
               USART3_Periph.CR1.TXEIE := 0;
            end if;
         end if;

         if USART3_Periph.ISR.RXNE = 1 then
            declare
               -- Reading RDR self-clears RXNE -- must happen either way,
               -- same reasoning as samv71-tiny's USART1 Handler reading
               -- RHR unconditionally.
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
      end Handler;

   end Controller;

   procedure Put (Item : Character) is
   begin
      Controller.Put (Item);
   end Put;

   procedure Put_Line (Item : String) is
   begin
      for C of Item loop
         Put (C);
      end loop;
      Put (ASCII.CR);
      Put (ASCII.LF);
   end Put_Line;

   procedure Get (Item : out Character) is
   begin
      Controller.Get (Item);
   end Get;

   procedure Initialize is
   begin
      RCC_Periph.AHB1ENR.GPIODEN := 1;
      RCC_Periph.APB1ENR.USART3EN := 1;

      -- PD8 (TX), PD9 (RX) to alternate-function mode (MODER binary
      -- "10" per pin) -- combined 4-bit field at bits[19:16] (pin9 high
      -- nibble, pin8 low nibble) = "1010" = 16#A#, same bit pattern
      -- ../../f722ze-tiny used, just through the typed GPIOD_Periph
      -- overlay instead of a raw Address import.
      GPIOD_Periph.MODER :=
        (As_Array => False,
         Val      => (GPIOD_Periph.MODER.Val and not 16#000F_0000#)
                      or 16#000A_0000#);

      -- AF7 (USART3) on PD8 (AFRH bits[3:0]) and PD9 (AFRH bits[7:4]).
      GPIOD_Periph.AFRH :=
        (As_Array => False,
         Val      => (GPIOD_Periph.AFRH.Val and not 16#0000_00FF#)
                      or 16#0000_0077#);

      -- 115200 baud at PCLK1 = 50MHz (HCLK/4 -- see System.BB.Parameters'
      -- APB1_PRE -- with HCLK = SYSCLK = 200MHz, AHB_PRE = DIV1). "New"
      -- F7 USART IP, 16x oversampling (OVER8 left at its reset value of
      -- 0 by not setting it in CR1 below): USARTDIV = PCLK1/(16*Baud) =
      -- 50_000_000/1_843_200 = 27.127(..), giving Mantissa=27,
      -- Fraction=round(0.127*16)=2 -- BRR = 27*16+2 = 434. Actual baud
      -- produced: 50_000_000/(16*27.125) = 115_207Hz, 0.0064% off
      -- nominal -- well within the UART's own tolerance. Needs the same
      -- oscilloscope/real-hardware confirmation flagged in
      -- ../../../KNOWN_ISSUES.md for SysTick timing once F767ZI is
      -- actually in hand -- PCLK1's own correctness depends on the HSE
      -- override in ../runtime-overrides/ being installed into the
      -- toolchain first.
      USART3_Periph.BRR :=
        (DIV_Fraction => 2, DIV_Mantissa => 27, Reserved_16_31 => 0);

      -- UE + TE + RE + RXNEIE. TXEIE is enabled on demand by Put/Handler
      -- above, same as f722ze-tiny's Bifrost.UART.
      USART3_Periph.CR1 :=
        (UE => 1, TE => 1, RE => 1, RXNEIE => 1, others => <>);

      -- No manual NVIC_ISER write, and no vector-table entry to extend
      -- (unlike f722ze-tiny) -- pragma Attach_Handler above, elaborated
      -- at library-level before Main's own body runs (standard Ravenscar
      -- task/protected-object activation order), is what enables
      -- USART3's NVIC line; GNARL does this as part of attaching the
      -- handler, same reason samv71-tiny's Samv71_Tiny.USART1.Initialize
      -- never touches NVIC either.
   end Initialize;

end Bifrost.UART;
