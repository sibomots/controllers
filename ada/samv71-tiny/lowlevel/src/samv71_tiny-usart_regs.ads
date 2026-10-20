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

-- Hand-written, in the same SVD-generated style as AdaCore's
-- Interfaces.SAM.UART (light-tasking-samv71's bundled runtime binds
-- UART0/UART1 but not USART0/1/2 -- this fills that gap for USART1,
-- which is what EDBG_COM (PA21/PB4) actually is on this board). Field
-- layouts cross-checked against the SAMV71 DFP's
-- include/component/usart.h, not guessed.
--
-- Not a child of Interfaces.SAM itself, unlike the package this was
-- first written as: GNAT rejects user-defined descendants of the
-- predefined Interfaces package ("user-defined descendants of package
-- Interfaces are not allowed") -- Interfaces.SAM is only permitted
-- because it ships as part of the runtime itself. Rooted under this
-- project's own Samv71_Tiny namespace instead, same as every other
-- project-owned package here.
--
-- Depending on Interfaces.SAM at all triggers GNAT's "internal GNAT
-- unit"/"non-portable and version-dependent" warning -- deliberately
-- silenced for this file in samv71_tiny.gpr, not fixed; see that
-- project file's Compiler package comment for the full accepted-risk
-- rationale.

pragma Ada_2012;
pragma Style_Checks (Off);

with System;
with Interfaces.SAM;

package Samv71_Tiny.USART_Regs is
   pragma Preelaborate;
   pragma No_Elaboration_Code_All;

   ---------------
   -- Registers --
   ---------------

   subtype USART_US_CR_RSTRX_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_RSTTX_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_RXEN_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_RXDIS_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_TXEN_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_TXDIS_Field is Interfaces.SAM.Bit;
   subtype USART_US_CR_RSTSTA_Field is Interfaces.SAM.Bit;

   --  Control Register
   type USART_US_CR_Register is record
      Reserved_0_1  : Interfaces.SAM.UInt2 := 16#0#;
      RSTRX         : USART_US_CR_RSTRX_Field := 16#0#;
      RSTTX         : USART_US_CR_RSTTX_Field := 16#0#;
      RXEN          : USART_US_CR_RXEN_Field := 16#0#;
      RXDIS         : USART_US_CR_RXDIS_Field := 16#0#;
      TXEN          : USART_US_CR_TXEN_Field := 16#0#;
      TXDIS         : USART_US_CR_TXDIS_Field := 16#0#;
      RSTSTA        : USART_US_CR_RSTSTA_Field := 16#0#;
      Reserved_9_31 : Interfaces.SAM.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_CR_Register use record
      Reserved_0_1  at 0 range 0 .. 1;
      RSTRX         at 0 range 2 .. 2;
      RSTTX         at 0 range 3 .. 3;
      RXEN          at 0 range 4 .. 4;
      RXDIS         at 0 range 5 .. 5;
      TXEN          at 0 range 6 .. 6;
      TXDIS         at 0 range 7 .. 7;
      RSTSTA        at 0 range 8 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   --  USART Mode of Operation
   subtype USART_US_MR_USART_MODE_Field is Interfaces.SAM.UInt4;
   --  Clock Selection
   subtype USART_US_MR_USCLKS_Field is Interfaces.SAM.UInt2;
   --  Character Length
   subtype USART_US_MR_CHRL_Field is Interfaces.SAM.UInt2;
   --  Synchronous Mode Select
   subtype USART_US_MR_SYNC_Field is Interfaces.SAM.Bit;
   --  Parity Type
   subtype USART_US_MR_PAR_Field is Interfaces.SAM.UInt3;
   --  Number of Stop Bits
   subtype USART_US_MR_NBSTOP_Field is Interfaces.SAM.UInt2;
   --  Channel Mode
   subtype USART_US_MR_CHMODE_Field is Interfaces.SAM.UInt2;

   --  Mode Register
   type USART_US_MR_Register is record
      USART_MODE     : USART_US_MR_USART_MODE_Field := 16#0#;
      USCLKS         : USART_US_MR_USCLKS_Field := 16#0#;
      CHRL           : USART_US_MR_CHRL_Field := 16#0#;
      SYNC           : USART_US_MR_SYNC_Field := 16#0#;
      PAR            : USART_US_MR_PAR_Field := 16#0#;
      NBSTOP         : USART_US_MR_NBSTOP_Field := 16#0#;
      CHMODE         : USART_US_MR_CHMODE_Field := 16#0#;
      Reserved_16_31 : Interfaces.SAM.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_MR_Register use record
      USART_MODE     at 0 range 0 .. 3;
      USCLKS         at 0 range 4 .. 5;
      CHRL           at 0 range 6 .. 7;
      SYNC           at 0 range 8 .. 8;
      PAR            at 0 range 9 .. 11;
      NBSTOP         at 0 range 12 .. 13;
      CHMODE         at 0 range 14 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype USART_US_IER_RXRDY_Field is Interfaces.SAM.Bit;
   subtype USART_US_IER_TXRDY_Field is Interfaces.SAM.Bit;

   --  Interrupt Enable Register
   type USART_US_IER_Register is record
      RXRDY         : USART_US_IER_RXRDY_Field := 16#0#;
      TXRDY         : USART_US_IER_TXRDY_Field := 16#0#;
      Reserved_2_31 : Interfaces.SAM.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_IER_Register use record
      RXRDY         at 0 range 0 .. 0;
      TXRDY         at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype USART_US_IDR_RXRDY_Field is Interfaces.SAM.Bit;
   subtype USART_US_IDR_TXRDY_Field is Interfaces.SAM.Bit;

   --  Interrupt Disable Register
   type USART_US_IDR_Register is record
      RXRDY         : USART_US_IDR_RXRDY_Field := 16#0#;
      TXRDY         : USART_US_IDR_TXRDY_Field := 16#0#;
      Reserved_2_31 : Interfaces.SAM.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_IDR_Register use record
      RXRDY         at 0 range 0 .. 0;
      TXRDY         at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype USART_US_IMR_RXRDY_Field is Interfaces.SAM.Bit;
   subtype USART_US_IMR_TXRDY_Field is Interfaces.SAM.Bit;

   --  Interrupt Mask Register
   type USART_US_IMR_Register is record
      RXRDY         : USART_US_IMR_RXRDY_Field;
      TXRDY         : USART_US_IMR_TXRDY_Field;
      Reserved_2_31 : Interfaces.SAM.UInt30;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_IMR_Register use record
      RXRDY         at 0 range 0 .. 0;
      TXRDY         at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype USART_US_CSR_RXRDY_Field is Interfaces.SAM.Bit;
   subtype USART_US_CSR_TXRDY_Field is Interfaces.SAM.Bit;

   --  Channel Status Register
   type USART_US_CSR_Register is record
      RXRDY         : USART_US_CSR_RXRDY_Field;
      TXRDY         : USART_US_CSR_TXRDY_Field;
      Reserved_2_31 : Interfaces.SAM.UInt30;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_CSR_Register use record
      RXRDY         at 0 range 0 .. 0;
      TXRDY         at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype USART_US_RHR_RXCHR_Field is Interfaces.SAM.UInt9;

   --  Receive Holding Register
   type USART_US_RHR_Register is record
      RXCHR         : USART_US_RHR_RXCHR_Field;
      Reserved_9_31 : Interfaces.SAM.UInt23;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_RHR_Register use record
      RXCHR         at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype USART_US_THR_TXCHR_Field is Interfaces.SAM.UInt9;

   --  Transmit Holding Register
   type USART_US_THR_Register is record
      TXCHR         : USART_US_THR_TXCHR_Field := 16#0#;
      Reserved_9_31 : Interfaces.SAM.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_THR_Register use record
      TXCHR         at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype USART_US_BRGR_CD_Field is Interfaces.SAM.UInt16;
   subtype USART_US_BRGR_FP_Field is Interfaces.SAM.UInt3;

   --  Baud Rate Generator Register
   type USART_US_BRGR_Register is record
      CD             : USART_US_BRGR_CD_Field := 16#0#;
      FP             : USART_US_BRGR_FP_Field := 16#0#;
      Reserved_19_31 : Interfaces.SAM.UInt13 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_BRGR_Register use record
      CD             at 0 range 0 .. 15;
      FP             at 0 range 16 .. 18;
      Reserved_19_31 at 0 range 19 .. 31;
   end record;

   subtype USART_US_WPMR_WPEN_Field is Interfaces.SAM.Bit;
   subtype USART_US_WPMR_WPKEY_Field is Interfaces.SAM.UInt24;

   --  Write Protection Mode Register
   type USART_US_WPMR_Register is record
      WPEN         : USART_US_WPMR_WPEN_Field := 16#0#;
      Reserved_1_7 : Interfaces.SAM.UInt7 := 16#0#;
      WPKEY        : USART_US_WPMR_WPKEY_Field := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for USART_US_WPMR_Register use record
      WPEN         at 0 range 0 .. 0;
      Reserved_1_7 at 0 range 1 .. 7;
      WPKEY        at 0 range 8 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Universal Synchronous Asynchronous Receiver Transmitter
   type USART_Peripheral is record
      US_CR   : aliased USART_US_CR_Register;
      US_MR   : aliased USART_US_MR_Register;
      US_IER  : aliased USART_US_IER_Register;
      US_IDR  : aliased USART_US_IDR_Register;
      US_IMR  : aliased USART_US_IMR_Register;
      US_CSR  : aliased USART_US_CSR_Register;
      US_RHR  : aliased USART_US_RHR_Register;
      US_THR  : aliased USART_US_THR_Register;
      US_BRGR : aliased USART_US_BRGR_Register;
      US_WPMR : aliased USART_US_WPMR_Register;
   end record
     with Volatile;

   for USART_Peripheral use record
      US_CR   at 16#0#  range 0 .. 31;
      US_MR   at 16#4#  range 0 .. 31;
      US_IER  at 16#8#  range 0 .. 31;
      US_IDR  at 16#C#  range 0 .. 31;
      US_IMR  at 16#10# range 0 .. 31;
      US_CSR  at 16#14# range 0 .. 31;
      US_RHR  at 16#18# range 0 .. 31;
      US_THR  at 16#1C# range 0 .. 31;
      US_BRGR at 16#20# range 0 .. 31;
      US_WPMR at 16#E4# range 0 .. 31;
   end record;

   --  Universal Synchronous Asynchronous Receiver Transmitter
   USART0_Periph : aliased USART_Peripheral
     with Import, Address => Interfaces.SAM.USART0_Base;

   --  Universal Synchronous Asynchronous Receiver Transmitter
   USART1_Periph : aliased USART_Peripheral
     with Import, Address => Interfaces.SAM.USART1_Base;

   --  Universal Synchronous Asynchronous Receiver Transmitter
   USART2_Periph : aliased USART_Peripheral
     with Import, Address => Interfaces.SAM.USART2_Base;

end Samv71_Tiny.USART_Regs;
