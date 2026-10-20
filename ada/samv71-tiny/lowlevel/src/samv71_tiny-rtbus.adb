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

with Interfaces; use Interfaces;
with Samv71_Tiny.CRC16;
with Samv71_Tiny.CRC32;

package body Samv71_Tiny.RTBus is

   CRC32_Start_Val : constant Unsigned_32 := 0;

   -- Plain Unsigned_32 wants 4-byte alignment; these three overlay a
   -- 1-byte-aligned Byte_Array at a byte offset with no alignment
   -- guarantee at all (same reasoning as the record types' explicit
   -- Alignment => 1 in the spec -- see that comment). Argument values
   -- and the trailing payload CRC32 are written/read as plain native
   -- 4-byte values by rtbus.c (not byte-split), so this type, not
   -- Unsigned_32 directly, is what Target/Crc_Slot/Packet_Crc32 below
   -- are declared as.
   type Unaligned_U32 is new Unsigned_32
     with Alignment => 1;

   procedure Set_Frame_Sync (Frame : in out RTMessage_t) is
   begin
      Frame.Frame_Sync_LSB := 16#55#;
      Frame.Frame_Sync_MSB := 16#AA#;
   end Set_Frame_Sync;

   procedure Initiate_Hdr
     (Frame               : in out RTMessage_t;
      PID                 : Byte;
      PVer                : Byte;
      Remote_Terminal_Id  : Byte;
      Response            : Byte)
   is
   begin
      Frame.RTHdr.Protocol_Id        := PID;
      Frame.RTHdr.Protocol_Version   := PVer;
      Frame.RTHdr.Remote_Terminal_Id := Remote_Terminal_Id;
      Frame.RTHdr.Response           := Response;
      Frame.RTHdr.Reserved_2         := 16#FFFF#;
      Frame.RTHdr.Payload_Size_LSB   := 0;
      Frame.RTHdr.Payload_Size_MSB   := 0;
      Frame.RTHdr.Timestamp          := 0;
      Frame.RTHdr.Hdr_Crc16_LSB      := 0;
      Frame.RTHdr.Hdr_Crc16_MSB      := 0;
   end Initiate_Hdr;

   procedure Preamble
     (Frame       : in out RTMessage_t;
      Cmd_Id      : Unsigned_16;
      Target_Id   : Unsigned_16;
      Instance_Id : Unsigned_16;
      Num_Args    : Unsigned_16)
   is
   begin
      Frame.RTPayload_Preamble.Cmd_Id_LSB      := Byte (Cmd_Id and 16#FF#);
      Frame.RTPayload_Preamble.Cmd_Id_MSB      := Byte (Shift_Right (Cmd_Id, 8) and 16#FF#);
      Frame.RTPayload_Preamble.Target_Id_LSB   := Byte (Target_Id and 16#FF#);
      Frame.RTPayload_Preamble.Target_Id_MSB   := Byte (Shift_Right (Target_Id, 8) and 16#FF#);
      Frame.RTPayload_Preamble.Instance_Id_LSB := Byte (Instance_Id and 16#FF#);
      Frame.RTPayload_Preamble.Instance_Id_MSB := Byte (Shift_Right (Instance_Id, 8) and 16#FF#);
      Frame.RTPayload_Preamble.Arg_Count_LSB   := Byte (Num_Args and 16#FF#);
      Frame.RTPayload_Preamble.Arg_Count_MSB   := Byte (Shift_Right (Num_Args, 8) and 16#FF#);
   end Preamble;

   function Get_Param_Count (Frame : RTMessage_t) return Unsigned_16 is
   begin
      return Unsigned_16 (Frame.RTPayload_Preamble.Arg_Count_LSB) or
             Shift_Left (Unsigned_16 (Frame.RTPayload_Preamble.Arg_Count_MSB), 8);
   end Get_Param_Count;

   procedure Update_Payload_Size (Frame : in out RTMessage_t) is
      Arg_Count : constant Unsigned_16 :=
        Unsigned_16 (Frame.RTPayload_Preamble.Arg_Count_LSB) +
        Shift_Left (Unsigned_16 (Frame.RTPayload_Preamble.Arg_Count_MSB), 8);
      Payload_Size : constant Unsigned_16 :=
        Unsigned_16 (RTPayHeader_Size) + Arg_Count * 4;
   begin
      Frame.RTHdr.Payload_Size_LSB := Byte (Payload_Size and 16#FF#);
      Frame.RTHdr.Payload_Size_MSB := Byte (Shift_Right (Payload_Size, 8) and 16#FF#);
   end Update_Payload_Size;

   procedure Update_Header_Crc (Frame : in out RTMessage_t) is
      Header_Bytes : Byte_Array (0 .. RTHeader_Size - 1);
      for Header_Bytes'Address use Frame.RTHdr'Address;
      pragma Import (Ada, Header_Bytes);

      Header_Crc : constant Unsigned_16 :=
        Samv71_Tiny.CRC16.Compute (Header_Bytes (0 .. RTHeader_Size - 3));
   begin
      Frame.RTHdr.Hdr_Crc16_LSB := Byte (Header_Crc and 16#FF#);
      Frame.RTHdr.Hdr_Crc16_MSB := Byte (Shift_Right (Header_Crc, 8) and 16#FF#);
   end Update_Header_Crc;

   procedure Append_Parameter
     (Buffer : in out Byte_Array;
      Idx    : Unsigned_16;
      Arg    : Unsigned_32)
   is
      Offset : constant Natural :=
        Buffer'First + RTMessage_Size + 4 * Natural (Idx);
      Target : Unaligned_U32;
      for Target'Address use Buffer (Offset)'Address;
      pragma Import (Ada, Target);
   begin
      Target := Unaligned_U32 (Arg);
   end Append_Parameter;

   procedure Update_Payload_Crc (Buffer : in out Byte_Array) is
      Frame : RTMessage_t;
      for Frame'Address use Buffer (Buffer'First)'Address;
      pragma Import (Ada, Frame);

      Arg_Count     : constant Natural := Natural (Get_Param_Count (Frame));
      Payload_Start : constant Natural := Buffer'First + 2 + RTHeader_Size;
      Num_Crc_Bytes : constant Natural := RTPayHeader_Size + 4 * Arg_Count;

      Payload_Crc : constant Unsigned_32 :=
        Samv71_Tiny.CRC32.Compute
          (CRC32_Start_Val,
           Buffer (Payload_Start .. Payload_Start + Num_Crc_Bytes - 1));

      Crc_Slot : Unaligned_U32;
      for Crc_Slot'Address use
        Buffer (Buffer'First + RTMessage_Size + 4 * Arg_Count)'Address;
      pragma Import (Ada, Crc_Slot);
   begin
      Crc_Slot := Unaligned_U32 (Payload_Crc);
   end Update_Payload_Crc;

   function Verify_Frame_Sync (Frame : RTMessage_t) return Boolean is
   begin
      return Frame.Frame_Sync_LSB = 16#55# and then Frame.Frame_Sync_MSB = 16#AA#;
   end Verify_Frame_Sync;

   function Verify_RT_Address (Frame : RTMessage_t) return Boolean is
   begin
      case Frame.RTHdr.Remote_Terminal_Id is
         when 16#00# | 16#01# | 16#02# => return True;
         when others                   => return False;
      end case;
   end Verify_RT_Address;

   function Verify_Header_Crc (Frame : RTMessage_t) return Boolean is
      Header_Bytes : Byte_Array (0 .. RTHeader_Size - 1);
      for Header_Bytes'Address use Frame.RTHdr'Address;
      pragma Import (Ada, Header_Bytes);

      Packet_Crc16 : constant Unsigned_16 :=
        Unsigned_16 (Frame.RTHdr.Hdr_Crc16_LSB) +
        Shift_Left (Unsigned_16 (Frame.RTHdr.Hdr_Crc16_MSB), 8);
   begin
      return Packet_Crc16 =
        Samv71_Tiny.CRC16.Compute (Header_Bytes (0 .. RTHeader_Size - 3));
   end Verify_Header_Crc;

   function Verify_Target_Id (Frame : RTMessage_t) return Boolean is
      Target_Id : constant Unsigned_16 :=
        Unsigned_16 (Frame.RTPayload_Preamble.Target_Id_LSB) +
        Shift_Left (Unsigned_16 (Frame.RTPayload_Preamble.Target_Id_MSB), 8);
   begin
      case Target_Id is
         when 16#0000# | 16#0001# | 16#0002# => return True;
         when others                         => return False;
      end case;
   end Verify_Target_Id;

   function Verify_Instance_Id (Frame : RTMessage_t) return Boolean is
      Instance_Id : constant Unsigned_16 :=
        Unsigned_16 (Frame.RTPayload_Preamble.Instance_Id_LSB) +
        Shift_Left (Unsigned_16 (Frame.RTPayload_Preamble.Instance_Id_MSB), 8);
   begin
      case Instance_Id is
         when 16#0000# | 16#0001# | 16#0002# => return True;
         when others                         => return False;
      end case;
   end Verify_Instance_Id;

   function Verify_Payload_Crc (Buffer : Byte_Array) return Boolean is
      Frame : RTMessage_t;
      for Frame'Address use Buffer (Buffer'First)'Address;
      pragma Import (Ada, Frame);

      Payload_Size : constant Natural :=
        Natural (Frame.RTHdr.Payload_Size_LSB) +
        Natural (Frame.RTHdr.Payload_Size_MSB) * 256;

      Payload_Start : constant Natural := Buffer'First + 2 + RTHeader_Size;

      Packet_Crc32 : Unaligned_U32;
      for Packet_Crc32'Address use
        Buffer (Payload_Start + Payload_Size)'Address;
      pragma Import (Ada, Packet_Crc32);

      Calculated_Crc32 : constant Unsigned_32 :=
        Samv71_Tiny.CRC32.Compute
          (CRC32_Start_Val,
           Buffer (Payload_Start .. Payload_Start + Payload_Size - 1));
   begin
      return Unsigned_32 (Packet_Crc32) = Calculated_Crc32;
   end Verify_Payload_Crc;

   function Validate_RT_Message (Buffer : Byte_Array) return Boolean is
      Frame : RTMessage_t;
      for Frame'Address use Buffer (Buffer'First)'Address;
      pragma Import (Ada, Frame);
   begin
      if not Verify_Frame_Sync (Frame) then
         return False;
      end if;
      if not Verify_RT_Address (Frame) then
         return False;
      end if;
      if not Verify_Header_Crc (Frame) then
         return False;
      end if;
      if not Verify_Target_Id (Frame) then
         return False;
      end if;
      if not Verify_Instance_Id (Frame) then
         return False;
      end if;
      if not Verify_Payload_Crc (Buffer) then
         return False;
      end if;
      return True;
   end Validate_RT_Message;

   procedure Construct_RT_Message
     (Buffer      : in out Byte_Array;
      FSync       : Unsigned_16;
      PID         : Byte;
      PVer        : Byte;
      RT_Id       : Byte;
      Cmd_Id      : Unsigned_16;
      Target_Id   : Unsigned_16;
      Instance_Id : Unsigned_16;
      Args        : Arg_Array)
   is
      Frame : RTMessage_t;
      for Frame'Address use Buffer (Buffer'First)'Address;
      pragma Import (Ada, Frame);
   begin
      Frame.Frame_Sync_LSB := Byte (FSync and 16#FF#);
      Frame.Frame_Sync_MSB := Byte (Shift_Right (FSync, 8) and 16#FF#);

      Initiate_Hdr (Frame, PID, PVer, RT_Id, 0);
      Preamble (Frame, Cmd_Id, Target_Id, Instance_Id, Unsigned_16 (Args'Length));
      Update_Payload_Size (Frame);
      Update_Header_Crc (Frame);

      for I in Args'Range loop
         Append_Parameter (Buffer, Unsigned_16 (I - Args'First), Args (I));
      end loop;

      Update_Payload_Crc (Buffer);
   end Construct_RT_Message;

end Samv71_Tiny.RTBus;
