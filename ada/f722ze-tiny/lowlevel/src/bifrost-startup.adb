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
--
-- Follows the standard, documented GNAT bare-metal pattern. If the
-- linker ever complains about Reset_Handler/_estack/_sdata/etc., start
-- here -- those names have to match config/stm32f722ze.ld exactly.

with System; use System;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements;
with System.Address_To_Access_Conversions;
with Bifrost.UART;

package body Bifrost.Startup is

   -- Linker-provided symbols (see config/stm32f722ze.ld). Only their
   -- addresses matter -- the "value" at these symbols is meaningless.
   -- Same trick the C startup code used via "extern uint32_t _estack;"
   -- then "&_estack".
   Estack    : Integer with Import, Convention => C, External_Name => "_estack";
   Sdata     : Integer with Import, Convention => C, External_Name => "_sdata";
   Edata     : Integer with Import, Convention => C, External_Name => "_edata";
   Sidata    : Integer with Import, Convention => C, External_Name => "_sidata";
   Bss_Start : Integer with Import, Convention => C, External_Name => "bss_start";
   Bss_End   : Integer with Import, Convention => C, External_Name => "bss_end";

   -- GNAT/gnatbind generates a C-callable "main" by default (same
   -- default behavior whether the target is hosted or bare-metal) that
   -- internally calls adainit, the designated Ada main procedure
   -- (app/src/main.adb, per the .gpr "for Main" attribute), then
   -- adafinal. Calling it here mirrors exactly how the C Reset_Handler
   -- called main() -- Ada's elaboration order is handled entirely
   -- inside that generated code, not hand-rolled here.
   procedure GNAT_Main with Import, Convention => C, External_Name => "main";

   procedure Default_Handler
     with Export, Convention => C, External_Name => "Default_Handler";

   procedure Default_Handler is
   begin
      loop
         Asm ("bkpt #1", Volatile => True);
      end loop;
   end Default_Handler;

   -- Core Cortex-M exception vectors (16 entries: initial SP + 15
   -- exception slots) plus peripheral IRQ entries up through USART3
   -- (IRQn 39, vector index 16 + 39 = 55) -- the only peripheral
   -- interrupt this program currently enables (Bifrost.UART.Initialize
   -- sets NVIC_ISER1's bit 7). Every other IRQ slot in between still
   -- lands on Default_Handler, same as the C vector table's own
   -- "everything unused aliases to Default_Handler" convention, just
   -- without porting all 128 of its entries since nothing past USART3
   -- is used here.
   --
   -- Every index below is written explicitly -- do NOT collapse the
   -- repeated Default_Handler'Address entries into "others =>". Tried
   -- that first; confirmed via a from-scratch isolated reproduction
   -- (compile to .s and inspect) that GNAT-FSF-builds 15.3.0 silently
   -- drops the initializer for a `constant` array using
   -- "others => <address-of-symbol>" when the array is Linker_Section'd
   -- and Export'd -- it emits an uninitialized ".space" directive
   -- instead of relocatable ".word" entries, with no warning or error.
   -- All-explicit associations (confirmed in the same reproduction)
   -- compile correctly. This cost a real "vector table is silently all
   -- zeros" bug once -- worth never reintroducing by going back to
   -- "others" here, even though the real cause was this specific
   -- compiler limitation rather than anything wrong with the Ada
   -- itself.
   type Vector_Table_Type is array (0 .. 55) of System.Address;

   Vector_Table : constant Vector_Table_Type :=
     (0  => Estack'Address,
      1  => Reset_Handler'Address,
      2  => Default_Handler'Address,  -- NMI
      3  => Default_Handler'Address,  -- HardFault
      4  => Default_Handler'Address,  -- MemManage
      5  => Default_Handler'Address,  -- BusFault
      6  => Default_Handler'Address,  -- UsageFault
      7  => System.Null_Address,
      8  => System.Null_Address,
      9  => System.Null_Address,
      10 => System.Null_Address,
      11 => Default_Handler'Address,  -- SVCall
      12 => Default_Handler'Address,  -- DebugMonitor
      13 => System.Null_Address,
      14 => Default_Handler'Address,  -- PendSV
      15 => Default_Handler'Address,  -- SysTick
      16 => Default_Handler'Address,
      17 => Default_Handler'Address,
      18 => Default_Handler'Address,
      19 => Default_Handler'Address,
      20 => Default_Handler'Address,
      21 => Default_Handler'Address,
      22 => Default_Handler'Address,
      23 => Default_Handler'Address,
      24 => Default_Handler'Address,
      25 => Default_Handler'Address,
      26 => Default_Handler'Address,
      27 => Default_Handler'Address,
      28 => Default_Handler'Address,
      29 => Default_Handler'Address,
      30 => Default_Handler'Address,
      31 => Default_Handler'Address,
      32 => Default_Handler'Address,
      33 => Default_Handler'Address,
      34 => Default_Handler'Address,
      35 => Default_Handler'Address,
      36 => Default_Handler'Address,
      37 => Default_Handler'Address,
      38 => Default_Handler'Address,
      39 => Default_Handler'Address,
      40 => Default_Handler'Address,
      41 => Default_Handler'Address,
      42 => Default_Handler'Address,
      43 => Default_Handler'Address,
      44 => Default_Handler'Address,
      45 => Default_Handler'Address,
      46 => Default_Handler'Address,
      47 => Default_Handler'Address,
      48 => Default_Handler'Address,
      49 => Default_Handler'Address,
      50 => Default_Handler'Address,
      51 => Default_Handler'Address,
      52 => Default_Handler'Address,
      53 => Default_Handler'Address,
      54 => Default_Handler'Address,
      55 => Bifrost.UART.Interrupt_Handler'Address);  -- USART3 (IRQn 39)
   pragma Export (C, Vector_Table, "g_pfnVectors");
   pragma Linker_Section (Vector_Table, ".isr_vector");

   procedure Copy_Region (From, To, To_End : System.Address) is
      Src : System.Address := From;
      Dst : System.Address := To;
      use type System.Address;
      package Byte_Conv is new System.Address_To_Access_Conversions
        (System.Storage_Elements.Storage_Element);
      use System.Storage_Elements;
   begin
      while Dst < To_End loop
         Byte_Conv.To_Pointer (Dst).all := Byte_Conv.To_Pointer (Src).all;
         Src := Src + 1;
         Dst := Dst + 1;
      end loop;
   end Copy_Region;

   procedure Zero_Region (From, To_End : System.Address) is
      Dst : System.Address := From;
      use type System.Address;
      package Byte_Conv is new System.Address_To_Access_Conversions
        (System.Storage_Elements.Storage_Element);
      use System.Storage_Elements;
   begin
      while Dst < To_End loop
         Byte_Conv.To_Pointer (Dst).all := 0;
         Dst := Dst + 1;
      end loop;
   end Zero_Region;

   procedure Reset_Handler is
   begin
      Copy_Region (Sidata'Address, Sdata'Address, Edata'Address);
      Zero_Region (Bss_Start'Address, Bss_End'Address);
      GNAT_Main;
      loop
         Asm ("bkpt #1", Volatile => True);
      end loop;
   end Reset_Handler;

end Bifrost.Startup;
