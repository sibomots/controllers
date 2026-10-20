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
-- Interfaces.SAM.* packages -- the bundled runtime doesn't bind WDT at
-- all. Only WDT_MR is modeled (the one register this application
-- touches, to disable the watchdog -- it is enabled out of reset).
-- Field layout cross-checked against the SAMV71 DFP's
-- include/component/wdt.h.
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

package Samv71_Tiny.WDT_Regs is
   pragma Preelaborate;
   pragma No_Elaboration_Code_All;

   subtype WDT_MR_WDV_Field is Interfaces.SAM.UInt12;
   subtype WDT_MR_WDFIEN_Field is Interfaces.SAM.Bit;
   subtype WDT_MR_WDRSTEN_Field is Interfaces.SAM.Bit;
   subtype WDT_MR_WDDIS_Field is Interfaces.SAM.Bit;
   subtype WDT_MR_WDD_Field is Interfaces.SAM.UInt12;
   subtype WDT_MR_WDDBGHLT_Field is Interfaces.SAM.Bit;
   subtype WDT_MR_WDIDLEHLT_Field is Interfaces.SAM.Bit;

   --  Mode Register
   type WDT_WDT_MR_Register is record
      WDV            : WDT_MR_WDV_Field := 16#0#;
      WDFIEN         : WDT_MR_WDFIEN_Field := 16#0#;
      WDRSTEN        : WDT_MR_WDRSTEN_Field := 16#0#;
      Reserved_14_14 : Interfaces.SAM.Bit := 16#0#;
      WDDIS          : WDT_MR_WDDIS_Field := 16#0#;
      WDD            : WDT_MR_WDD_Field := 16#0#;
      WDDBGHLT       : WDT_MR_WDDBGHLT_Field := 16#0#;
      WDIDLEHLT      : WDT_MR_WDIDLEHLT_Field := 16#0#;
      Reserved_30_31 : Interfaces.SAM.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Size => 32,
          Bit_Order => System.Low_Order_First;

   for WDT_WDT_MR_Register use record
      WDV            at 0 range 0 .. 11;
      WDFIEN         at 0 range 12 .. 12;
      WDRSTEN        at 0 range 13 .. 13;
      Reserved_14_14 at 0 range 14 .. 14;
      WDDIS          at 0 range 15 .. 15;
      WDD            at 0 range 16 .. 27;
      WDDBGHLT       at 0 range 28 .. 28;
      WDIDLEHLT      at 0 range 29 .. 29;
      Reserved_30_31 at 0 range 30 .. 31;
   end record;

   --  Watchdog Timer
   type WDT_Peripheral is record
      WDT_MR : aliased WDT_WDT_MR_Register;
   end record
     with Volatile;

   for WDT_Peripheral use record
      WDT_MR at 16#4# range 0 .. 31;
   end record;

   --  Watchdog Timer
   WDT_Periph : aliased WDT_Peripheral
     with Import, Address => Interfaces.SAM.WDT_Base;

end Samv71_Tiny.WDT_Regs;
