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

with Samv71_Tiny.Exec_Cmd;

package body Samv71_Tiny.Cmd_Handler is

   function Get_Next_Token (Input : String; Pos : in out Natural) return String is
   begin
      if Pos > Input'Last then
         return "";
      end if;

      declare
         Start : constant Natural := Pos;
      begin
         while Pos <= Input'Last and then Input (Pos) /= ' ' loop
            Pos := Pos + 1;
         end loop;

         declare
            Tok : constant String := Input (Start .. Pos - 1);
         begin
            if Pos <= Input'Last then
               Pos := Pos + 1;
            else
               Pos := Input'Last + 1;
            end if;
            return Tok;
         end;
      end;
   end Get_Next_Token;

   function Get_Command_Id (Token : String) return Unsigned_16 is
   begin
      if Token = "cmda" then
         return CMDA;
      elsif Token = "cmdb" then
         return CMDB;
      elsif Token = "cmdc" then
         return CMDC;
      else
         return CMD_ID_ERRNO;
      end if;
   end Get_Command_Id;

   function Verify_Command_Id (Command_Id : Unsigned_16) return Boolean is
   begin
      case Command_Id is
         when CMDA | CMDB | CMDC => return True;
         when others             => return False;
      end case;
   end Verify_Command_Id;

   function Verify_Cmda (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean is
   begin
      return Args'Length = NUM_ARGS_CMDA;
   end Verify_Cmda;

   function Verify_Cmdb (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean is
   begin
      if Args'Length /= NUM_ARGS_CMDB then
         return False;
      end if;
      return Args (Args'First) >= LED_ID_LOWER and Args (Args'First) <= LED_ID_UPPER;
   end Verify_Cmdb;

   function Verify_Cmdc (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean is
   begin
      if Args'Length /= NUM_ARGS_CMDC then
         return False;
      end if;
      return Args (Args'First) >= LED_ID_LOWER and Args (Args'First) <= LED_ID_UPPER;
   end Verify_Cmdc;

   function Ascii_To_Uint32 (Ascii_Str : String) return Unsigned_32 is
      Val : Unsigned_32 := 0;
   begin
      for C of Ascii_Str loop
         Val := Val * 10 + Unsigned_32 (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Val;
   end Ascii_To_Uint32;

   procedure Create_Arg_Arr
     (Input    : String;
      Pos      : in out Natural;
      Args     : out Samv71_Tiny.RTBus.Arg_Array;
      Num_Args : out Natural)
   is
      Count : Natural := 0;
   begin
      loop
         declare
            Tok : constant String := Get_Next_Token (Input, Pos);
         begin
            exit when Tok'Length = 0;
            Args (Args'First + Count) := Ascii_To_Uint32 (Tok);
            Count := Count + 1;
         end;
      end loop;
      Num_Args := Count;
   end Create_Arg_Arr;

   function Handle_Command
     (Input     : String;
      Cmd_State : in out Parse_State_Array;
      Packet    : in out Byte_Array) return Boolean
   is
      Pos          : Natural := Input'First;
      Args         : Samv71_Tiny.RTBus.Arg_Array (0 .. ARG_ARR_SZ - 1);
      Num_Args     : Natural := 0;
      Cmd_Id       : Unsigned_16 := CMD_ID_ERRNO;
      Func_Success : Boolean;
      Finished     : Boolean := False;
      State        : Parse_State := Evaluate_Command;
   begin
      while not Finished loop
         case State is
            when Evaluate_Command =>
               declare
                  Tok : constant String := Get_Next_Token (Input, Pos);
               begin
                  Cmd_Id := Get_Command_Id (Tok);
               end;
               Func_Success := Verify_Command_Id (Cmd_Id);
               if not Func_Success then
                  State := Fail;
               else
                  Cmd_State (Natural (Cmd_Id)) := State;
                  State := Evaluate_Args;
               end if;

            when Evaluate_Args =>
               Cmd_State (Natural (Cmd_Id)) := State;
               Create_Arg_Arr (Input, Pos, Args, Num_Args);

               case Cmd_Id is
                  when CMDA   => Func_Success := Verify_Cmda (Args (0 .. Num_Args - 1));
                  when CMDB   => Func_Success := Verify_Cmdb (Args (0 .. Num_Args - 1));
                  when CMDC   => Func_Success := Verify_Cmdc (Args (0 .. Num_Args - 1));
                  when others => Func_Success := False;
               end case;

               if not Func_Success then
                  State := Fail;
               else
                  State := Create_Packet;
               end if;

            when Create_Packet =>
               Cmd_State (Natural (Cmd_Id)) := State;
               Samv71_Tiny.RTBus.Construct_RT_Message
                 (Packet, 16#AA55#, 16#80#, 16#01#, 16#01#,
                  Cmd_Id, 16#01#, 16#01#, Args (0 .. Num_Args - 1));
               State := Validate_Packet;

            when Validate_Packet =>
               Cmd_State (Natural (Cmd_Id)) := State;
               Func_Success := Samv71_Tiny.RTBus.Validate_RT_Message (Packet);
               if not Func_Success then
                  State := Fail;
               else
                  State := Done;
               end if;

            when Done =>
               Cmd_State (Natural (Cmd_Id)) := State;
               Samv71_Tiny.Exec_Cmd.Populate_Exec_Arr (Cmd_Id, Args (0 .. Num_Args - 1));
               Finished := True;

            when Fail =>
               if Cmd_Id /= CMD_ID_ERRNO then
                  Cmd_State (Natural (Cmd_Id)) := State;
               end if;
               return False;

            when Standby =>
               if Cmd_Id /= CMD_ID_ERRNO then
                  Cmd_State (Natural (Cmd_Id)) := State;
               end if;
               State := Fail;
         end case;
      end loop;

      return True;
   end Handle_Command;

end Samv71_Tiny.Cmd_Handler;
