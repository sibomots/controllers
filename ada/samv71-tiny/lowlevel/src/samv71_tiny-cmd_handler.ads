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

-- Direct port of rtbus/include/cmd_handler.h + rtbus/src/cmd_handler.c
-- -- tokenizer, cmda/cmdb/cmdc lookup, argument verification, and the
-- EVALUATE_COMMAND -> ... -> DONE/FAIL state machine, ported as-is
-- rather than redesigned, same as the rest of this port.
--
-- Command IDs are plain Unsigned_16 constants, not an Ada enumeration
-- type: CommandID_t's C values (CMDA=0, CMDB=1, CMDC=2) are plain ints
-- that interoperate freely with CMD_ID_ERRNO (0xFFFF, a sentinel
-- outside the valid command range) and with the cmd_id this ultimately
-- becomes on the wire (Samv71_Tiny.RTBus's Unsigned_16 Cmd_Id
-- parameter) -- an Ada enum type would need an extra "invalid"
-- enumerator or a wrapper type to carry that sentinel, adding
-- complexity a mechanical port doesn't need.
--
-- My_Strcmp doesn't get ported: Ada's predefined String "=" already
-- does exactly what the C function existed to work around (C has no
-- built-in string equality). Get_Next_Token's C signature takes a
-- "const uint8_t **const str" so it can both advance the caller's
-- cursor and signal exhaustion by setting *str to NULL -- ported here
-- as an in-out Natural cursor into a String, with Pos > Input'Last as
-- the exhausted sentinel (no NULL-pointer idiom needed); the returned
-- token's own String'Length replaces the separate tok_len return
-- value C needed.
with Interfaces;          use Interfaces;
with Samv71_Tiny.RTBus;

package Samv71_Tiny.Cmd_Handler is

   ARG_ARR_SZ    : constant := 16;
   CMD_ID_ERRNO  : constant Unsigned_16 := 16#FFFF#;

   NUM_CMDS      : constant := 3;

   CMDA : constant Unsigned_16 := 0;
   CMDB : constant Unsigned_16 := 1;
   CMDC : constant Unsigned_16 := 2;

   NUM_ARGS_CMDA : constant := 0;
   NUM_ARGS_CMDB : constant := 1;
   NUM_ARGS_CMDC : constant := 1;

   LED_ID_LOWER : constant Unsigned_32 := 0;
   LED_ID_UPPER : constant Unsigned_32 := 1;

   type Parse_State is
     (Evaluate_Command, Evaluate_Args, Create_Packet, Validate_Packet,
      Done, Fail, Standby);

   type Parse_State_Array is array (0 .. NUM_CMDS - 1) of Parse_State;

   function Get_Next_Token (Input : String; Pos : in out Natural) return String;

   function Get_Command_Id (Token : String) return Unsigned_16;

   function Verify_Command_Id (Command_Id : Unsigned_16) return Boolean;

   function Verify_Cmda (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean;
   function Verify_Cmdb (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean;
   function Verify_Cmdc (Args : Samv71_Tiny.RTBus.Arg_Array) return Boolean;

   function Ascii_To_Uint32 (Ascii_Str : String) return Unsigned_32;

   procedure Create_Arg_Arr
     (Input    : String;
      Pos      : in out Natural;
      Args     : out Samv71_Tiny.RTBus.Arg_Array;
      Num_Args : out Natural);

   function Handle_Command
     (Input     : String;
      Cmd_State : in out Parse_State_Array;
      Packet    : in out Byte_Array) return Boolean;

end Samv71_Tiny.Cmd_Handler;
