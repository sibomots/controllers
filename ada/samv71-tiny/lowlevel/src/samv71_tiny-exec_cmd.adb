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

-- Depending on Interfaces.SAM.PIO at all triggers GNAT's "internal GNAT
-- unit"/"non-portable and version-dependent" warning -- deliberately
-- silenced for this file in samv71_tiny.gpr, not fixed; see that
-- project file's Compiler package comment for the full accepted-risk
-- rationale.

with Interfaces.SAM;      use Interfaces.SAM;
with Interfaces.SAM.PIO; use Interfaces.SAM.PIO;
with Samv71_Tiny.Board;  use Samv71_Tiny.Board;

package body Samv71_Tiny.Exec_Cmd is

   Has_Args    : array (0 .. 2) of Boolean := (others => False);
   Stored_Arg0 : array (0 .. 2) of Unsigned_32 := (others => 0);

   procedure Initialize is
   begin
      PIOA_Periph.PIO_PER  := (As_Array => False, Val => 2 ** PA23);
      PIOA_Periph.PIO_OER  := (As_Array => False, Val => 2 ** PA23);
      PIOA_Periph.PIO_SODR := (As_Array => False, Val => 2 ** PA23);

      PIOC_Periph.PIO_PER  := (As_Array => False, Val => 2 ** PC9);
      PIOC_Periph.PIO_OER  := (As_Array => False, Val => 2 ** PC9);
      PIOC_Periph.PIO_SODR := (As_Array => False, Val => 2 ** PC9);
   end Initialize;

   procedure Render_Pins is
   begin
      for Cmd_Id in Has_Args'Range loop
         if Has_Args (Cmd_Id) then
            case Cmd_Id is
               when 0      => Exec_Cmda;
               when 1      => Exec_Cmdb (Stored_Arg0 (Cmd_Id));
               when 2      => Exec_Cmdc (Stored_Arg0 (Cmd_Id));
               when others => null;
            end case;
            Has_Args (Cmd_Id) := False;
            exit;
         end if;
      end loop;
   end Render_Pins;

   procedure Populate_Exec_Arr
     (Cmd_Id : Unsigned_16;
      Args   : Samv71_Tiny.RTBus.Arg_Array)
   is
   begin
      Has_Args := (others => False);
      if Args'Length > 0 then
         Stored_Arg0 (Natural (Cmd_Id)) := Args (Args'First);
      end if;
      Has_Args (Natural (Cmd_Id)) := True;
   end Populate_Exec_Arr;

   procedure Exec_Cmda is
   begin
      null;
   end Exec_Cmda;

   procedure Exec_Cmdb (Led_Id : Unsigned_32) is
   begin
      if Led_Id = 0 then
         PIOA_Periph.PIO_CODR := (As_Array => False, Val => 2 ** PA23);
      elsif Led_Id = 1 then
         PIOC_Periph.PIO_CODR := (As_Array => False, Val => 2 ** PC9);
      end if;
   end Exec_Cmdb;

   procedure Exec_Cmdc (Led_Id : Unsigned_32) is
   begin
      if Led_Id = 0 then
         PIOA_Periph.PIO_SODR := (As_Array => False, Val => 2 ** PA23);
      elsif Led_Id = 1 then
         PIOC_Periph.PIO_SODR := (As_Array => False, Val => 2 ** PC9);
      end if;
   end Exec_Cmdc;

end Samv71_Tiny.Exec_Cmd;
