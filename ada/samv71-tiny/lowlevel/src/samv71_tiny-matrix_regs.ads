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
-- Interfaces.SAM.* packages -- the bundled runtime doesn't bind MATRIX
-- at all. Only CCFG_SYSIO is modeled, and only its SYSIO4 field is
-- named: PB4 (USART1 TXD1 on this board) is one of the pins shared
-- with JTAG (TDI) that defaults to its JTAG function at reset and
-- needs this bit set to release it for GPIO/peripheral use. Field
-- layout cross-checked against the SAMV71 DFP's
-- include/component/matrix.h.
--
-- Not a child of Interfaces.SAM itself: see samv71_tiny-usart_regs.ads
-- for why ("user-defined descendants of package Interfaces are not
-- allowed").
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

package Samv71_Tiny.MATRIX_Regs is
   pragma Preelaborate;
   pragma No_Elaboration_Code_All;

   subtype CCFG_SYSIO_SYSIO4_Field is Interfaces.SAM.Bit;

   --  System I/O and CAN1 Configuration Register
   type MATRIX_CCFG_SYSIO_Register is record
      Reserved_0_3  : Interfaces.SAM.UInt4 := 16#0#;
      SYSIO4        : CCFG_SYSIO_SYSIO4_Field := 16#0#;
      Reserved_5_31 : Interfaces.SAM.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for MATRIX_CCFG_SYSIO_Register use record
      Reserved_0_3  at 0 range 0 .. 3;
      SYSIO4        at 0 range 4 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   --  Bus Matrix
   type MATRIX_Peripheral is record
      CCFG_SYSIO : aliased MATRIX_CCFG_SYSIO_Register;
   end record
     with Volatile;

   for MATRIX_Peripheral use record
      CCFG_SYSIO at 16#114# range 0 .. 31;
   end record;

   --  Bus Matrix
   MATRIX_Periph : aliased MATRIX_Peripheral
     with Import, Address => Interfaces.SAM.MATRIX_Base;

end Samv71_Tiny.MATRIX_Regs;
