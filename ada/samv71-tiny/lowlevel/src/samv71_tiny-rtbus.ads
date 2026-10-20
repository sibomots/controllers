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

-- Direct port of rtbus/include/rtpacket.h + rtbus/src/rtbus.c --
-- a MIL-1553-style packet format (frame sync, header, payload preamble,
-- arguments, payload CRC32), field for field.
--
-- Field layout note: rtpacket.h splits most multi-byte fields into
-- explicit lsb/msb uint8_t pairs (frame_sync, payload_size, hdr_crc16,
-- cmd_id, target_id, instance_id, arg_count) -- those are modeled below
-- as separate Byte components, matching the explicit byte-shifting
-- rtbus.c does when building/reading them. But RTHeader_t.timestamp and
-- .reserved_2 are plain native uint32_t/uint16_t fields in the C
-- struct, not split -- and rtbus.c's rtbus_append_parameter /
-- rtbus_update_payload_crc also write the argument values and the
-- trailing payload CRC32 as plain native 4-byte writes
-- (*(uint32_t*)ptr = value), not byte-split. Those are modeled below as
-- plain Interfaces.Unsigned_32/Unsigned_16 fields/overlays instead,
-- relying on this target's little-endian default Scalar_Storage_Order
-- matching C's native byte order on the same target -- not an
-- inconsistency to "fix", just mirroring exactly which fields the
-- original C code treated as wire-format-explicit versus which ones it
-- treated as plain native memory.
--
-- Alignment note: the C structs are declared
-- __attribute__((packed, aligned(1))) -- the "aligned(1)" is doing real
-- work, not decoration: it's what lets the C code place an RTMessage_t*
-- at an arbitrary, unaligned byte offset inside a larger raw buffer
-- (which is exactly what happens here -- these structs always overlay
-- the front of a caller-owned byte buffer, not a standalone, naturally-
-- aligned object). The three record types below carry "with Pack" for
-- tight bit layout but need the matching explicit Alignment => 1 too --
-- without it, GNAT picked a natural alignment of 8 for RTMessage_t
-- (driven by its Unsigned_32/Unsigned_16 components), and every
-- 'Address overlay onto a plain (1-byte-aligned) Byte_Array in the body
-- triggered real "program execution may be erroneous (RM 13.3(27))"
-- warnings -- a genuine alignment-safety gap, not noise to suppress.
--
-- The circular rtbus.c/cmd_handler.c dependency does not port as-is:
-- in C, validate_rt_message calls cmd_handler.c's verify_command_id and
-- the per-command verify_cmda/b/c, and cmd_handler.c's handle_command
-- calls back into rtbus.c's construct_rt_message/validate_rt_message --
-- fine for separately-compiled, separately-linked C translation units,
-- but Ada's package spec dependencies can't be circular this way.
-- Validate_RT_Message below covers only protocol-level checks (frame
-- sync, RT address, header CRC, target id, instance id, payload CRC);
-- command-id and per-command argument validation becomes Samv71_Tiny.
-- Cmd_Handler's own responsibility in Phase 5, called alongside this
-- rather than from inside it -- a deliberate, scoped adjustment to fit
-- Ada's module system, not a behavioral redesign of what gets checked
-- overall.
with Interfaces;

package Samv71_Tiny.RTBus is

   type RTHeader_t is record
      Protocol_Id        : Byte := 0;
      Protocol_Version   : Byte := 0;
      Remote_Terminal_Id : Byte := 0;
      Response           : Byte := 0;
      Payload_Size_LSB   : Byte := 0;
      Payload_Size_MSB   : Byte := 0;
      Timestamp          : Interfaces.Unsigned_32 := 0;
      Reserved_2         : Interfaces.Unsigned_16 := 16#FFFF#;
      Hdr_Crc16_LSB      : Byte := 0;
      Hdr_Crc16_MSB      : Byte := 0;
   end record
     with Pack, Alignment => 1;

   type RTPayHeader_t is record
      Cmd_Id_LSB      : Byte := 0;
      Cmd_Id_MSB      : Byte := 0;
      Target_Id_LSB   : Byte := 0;
      Target_Id_MSB   : Byte := 0;
      Instance_Id_LSB : Byte := 0;
      Instance_Id_MSB : Byte := 0;
      Arg_Count_LSB   : Byte := 0;
      Arg_Count_MSB   : Byte := 0;
   end record
     with Pack, Alignment => 1;

   type RTMessage_t is record
      Frame_Sync_LSB     : Byte := 0;
      Frame_Sync_MSB     : Byte := 0;
      RTHdr              : RTHeader_t;
      RTPayload_Preamble : RTPayHeader_t;
   end record
     with Pack, Alignment => 1;

   type Arg_Array is array (Natural range <>) of Interfaces.Unsigned_32;

   -- Byte sizes of the three record types above, named rather than
   -- computed inline with 'Size/8 everywhere offsets into a raw buffer
   -- are needed below. Cross-checked against the types' actual 'Size
   -- at compile time, not just asserted.
   RTHeader_Size    : constant := 14;
   RTPayHeader_Size : constant := 8;
   RTMessage_Size   : constant := 24;

   pragma Compile_Time_Error
     (RTHeader_t'Size /= RTHeader_Size * 8, "RTHeader_Size mismatch");
   pragma Compile_Time_Error
     (RTPayHeader_t'Size /= RTPayHeader_Size * 8, "RTPayHeader_Size mismatch");
   pragma Compile_Time_Error
     (RTMessage_t'Size /= RTMessage_Size * 8, "RTMessage_Size mismatch");

   procedure Set_Frame_Sync (Frame : in out RTMessage_t);

   procedure Initiate_Hdr
     (Frame               : in out RTMessage_t;
      PID                 : Byte;
      PVer                : Byte;
      Remote_Terminal_Id  : Byte;
      Response            : Byte);

   procedure Preamble
     (Frame      : in out RTMessage_t;
      Cmd_Id     : Interfaces.Unsigned_16;
      Target_Id  : Interfaces.Unsigned_16;
      Instance_Id : Interfaces.Unsigned_16;
      Num_Args   : Interfaces.Unsigned_16);

   procedure Update_Payload_Size (Frame : in out RTMessage_t);

   procedure Update_Header_Crc (Frame : in out RTMessage_t);

   function Get_Param_Count (Frame : RTMessage_t) return Interfaces.Unsigned_16;

   -- Need the raw buffer, not just the fixed-size RTMessage_t prefix:
   -- the argument values and the trailing payload CRC32 live past it,
   -- at an offset depending on the (variable) argument count.
   procedure Append_Parameter
     (Buffer : in out Byte_Array;
      Idx    : Interfaces.Unsigned_16;
      Arg    : Interfaces.Unsigned_32);

   procedure Update_Payload_Crc (Buffer : in out Byte_Array);

   function Verify_Frame_Sync (Frame : RTMessage_t) return Boolean;
   function Verify_RT_Address (Frame : RTMessage_t) return Boolean;
   function Verify_Header_Crc (Frame : RTMessage_t) return Boolean;
   function Verify_Target_Id (Frame : RTMessage_t) return Boolean;
   function Verify_Instance_Id (Frame : RTMessage_t) return Boolean;
   function Verify_Payload_Crc (Buffer : Byte_Array) return Boolean;

   -- Protocol-level checks only -- see the package comment above for
   -- why command-id/argument validation isn't included here.
   function Validate_RT_Message (Buffer : Byte_Array) return Boolean;

   procedure Construct_RT_Message
     (Buffer              : in out Byte_Array;
      FSync               : Interfaces.Unsigned_16;
      PID                 : Byte;
      PVer                : Byte;
      RT_Id               : Byte;
      Cmd_Id              : Interfaces.Unsigned_16;
      Target_Id           : Interfaces.Unsigned_16;
      Instance_Id         : Interfaces.Unsigned_16;
      Args                : Arg_Array);

end Samv71_Tiny.RTBus;
