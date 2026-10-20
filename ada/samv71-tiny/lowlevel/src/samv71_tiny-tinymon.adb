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
with System.Storage_Elements; use System.Storage_Elements;
with Samv71_Tiny.USART1;
with Samv71_Tiny.Cmd_Handler; use Samv71_Tiny.Cmd_Handler;
with Samv71_Tiny.Exec_Cmd;
with Samv71_Tiny.RTBus;

package body Samv71_Tiny.TinyMon is

   TM_BUF_SIZ : constant := 256;

   -- sizeof(RTMessage_t) + 4 (trailing payload CRC32) +
   -- 4*ARG_ARR_SZ (the generic protocol-wide max argument count) --
   -- a generous fixed bound for Packet, same role MEMSIZE (1024, an
   -- arbitrary over-allocation not tied to anything) played in C.
   Packet_Buf_Size : constant :=
     Samv71_Tiny.RTBus.RTMessage_Size + 4 + 4 * Samv71_Tiny.Cmd_Handler.ARG_ARR_SZ;

   Prompt : constant String := ASCII.CR & ASCII.LF & "TinyMon> ";

   Help_Dialogue : constant String :=
     ASCII.CR & ASCII.LF & ASCII.LF &
     "Enter one of the following commands and its parameters:" &
     ASCII.CR & ASCII.LF &
     "cmda" & ASCII.CR & ASCII.LF &
     "cmdb led_id (0 <= led_id <= 1)" & ASCII.CR & ASCII.LF &
     "cmdc led_id (0 <= led_id <= 1)" & ASCII.CR & ASCII.LF & ASCII.LF &
     "i.e. cmdb 1" & ASCII.CR & ASCII.LF;

   Welcome : constant String :=
     ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF &
     "This is TinyMon" & ASCII.CR & ASCII.LF &
     "Type 'help' for more information." & ASCII.CR & ASCII.LF &
     ASCII.CR & ASCII.LF;

   BS_Sequence : constant String := ASCII.BS & " " & ASCII.BS;
   CRLF        : constant String := ASCII.CR & ASCII.LF;

   Buffer    : String (1 .. TM_BUF_SIZ);
   Idx       : Natural := 0;
   Cmd_State : Parse_State_Array := (others => Standby);
   Packet    : Byte_Array (0 .. Packet_Buf_Size - 1) := (others => 0);

   procedure Put_String (S : String) is
   begin
      for C of S loop
         Samv71_Tiny.USART1.Put (C);
      end loop;
   end Put_String;

   procedure Show_Prompt is
   begin
      Put_String (Prompt);
   end Show_Prompt;

   procedure Show_Help is
   begin
      Put_String (Help_Dialogue);
   end Show_Help;

   -- Direct port of nibble_to_ascii + the hex-digit half of
   -- build_cmd_packet_str's byte-dump loop.
   function Nibble_To_Hex (N : Natural) return Character is
      Hex : constant String := "0123456789ABCDEF";
   begin
      return Hex (N + 1);
   end Nibble_To_Hex;

   procedure Put_Byte_Hex (B : Byte) is
   begin
      Samv71_Tiny.USART1.Put (Nibble_To_Hex (Natural (B / 16)));
      Samv71_Tiny.USART1.Put (Nibble_To_Hex (Natural (B mod 16)));
   end Put_Byte_Hex;

   -- Direct port of hex_to_ascii, printing straight to the console
   -- instead of building a separate address_string buffer first.
   procedure Put_Address_Hex (Addr : Integer_Address) is
      Remaining : Integer_Address := Addr;
      Digits_Rev : String (1 .. 8);
   begin
      Samv71_Tiny.USART1.Put ('0');
      Samv71_Tiny.USART1.Put ('x');
      for I in reverse Digits_Rev'Range loop
         Digits_Rev (I) := Nibble_To_Hex (Natural (Remaining mod 16));
         Remaining := Remaining / 16;
      end loop;
      Put_String (Digits_Rev);
   end Put_Address_Hex;

   -- Direct port of build_cmd_packet_str, printing each row as it's
   -- computed instead of filling tm_packet_str first.
   procedure Show_Packet_Dump (Num_Args : Natural) is
      Packet_Size : constant Natural :=
        Samv71_Tiny.RTBus.RTMessage_Size + 4 + 4 * Num_Args;
      Row : Natural := 0;
   begin
      for Byte_Counter in 0 .. Packet_Size - 1 loop
         if Byte_Counter mod 16 = 0 then
            Put_String (CRLF);
            Put_Address_Hex (To_Integer (Packet (Packet'First + 16 * Row)'Address));
            Put_String (": ");
            Row := Row + 1;
         end if;
         Put_Byte_Hex (Packet (Packet'First + Byte_Counter));
         Samv71_Tiny.USART1.Put (' ');
      end loop;
      Put_String (CRLF);
   end Show_Packet_Dump;

   -- Direct port of build_cmd_status_str, printing each line as it's
   -- computed. The per-command status name comes from Parse_State'Image
   -- directly -- Ada's enumeration 'Image already returns the literal's
   -- spelling in upper case (EVALUATE_COMMAND, DONE, FAIL, STANDBY, ...),
   -- exactly matching the C version's hand-written
   -- evaluate_command_str/done_str/fail_str/standby_str table, so that
   -- table doesn't need porting at all.
   Cmd_Name : constant array (0 .. NUM_CMDS - 1) of String (1 .. 4) :=
     ("cmda", "cmdb", "cmdc");

   procedure Show_Status is
   begin
      Put_String (CRLF);
      for I in Cmd_State'Range loop
         Put_String (Cmd_Name (I));
         Put_String (": ");
         Put_String (Parse_State'Image (Cmd_State (I)));
         Put_String (CRLF);
      end loop;
   end Show_Status;

   procedure Clear_Buffer is
   begin
      Idx := 0;
   end Clear_Buffer;

   -- Direct port of dispatch_cmd + the render_pins()/print_user_messages()
   -- call sequence RenderOutput used to drive from main.c's superloop
   -- (see the package spec comment for why that split doesn't carry
   -- over).
   procedure Dispatch_Cmd is
      Line : constant String := Buffer (1 .. Idx);
   begin
      if Line = "help" or else Line = "h" then
         Show_Help;
      else
         Cmd_State := (others => Standby);
         Packet := (others => 0);

         declare
            Success : constant Boolean :=
              Samv71_Tiny.Cmd_Handler.Handle_Command (Line, Cmd_State, Packet);
            Frame : Samv71_Tiny.RTBus.RTMessage_t;
            for Frame'Address use Packet (Packet'First)'Address;
            pragma Import (Ada, Frame);
         begin
            if Success then
               Samv71_Tiny.Exec_Cmd.Render_Pins;
               Show_Packet_Dump (Natural (Samv71_Tiny.RTBus.Get_Param_Count (Frame)));
            end if;
            Show_Status;
         end;
      end if;

      Clear_Buffer;
      Show_Prompt;
   end Dispatch_Cmd;

   -- Direct port of parse(), minus the tm_input staging byte and the
   -- process_user_input() poll wrapper -- Get (below, in the console
   -- task) already blocks until a real byte is available and hands it
   -- straight to this procedure.
   --
   -- One real bug in the C original, not carried over: parse() guards
   -- with "if (tm_idx > TM_BUF_SIZ) return;" -- an off-by-one that lets
   -- tm_idx reach exactly TM_BUF_SIZ and then write one byte past the
   -- end of tm_buffer[TM_BUF_SIZ] on the next character (a real latent
   -- buffer overflow, just one unlikely to be hit by a human typing at
   -- a prompt). Ada's bounds-checked Buffer(Idx) would turn that into a
   -- raised Constraint_Error instead of silent corruption -- still not
   -- the right fix. The guard below uses ">=" instead, matching what
   -- the C code's intent clearly was.
   procedure Parse (C : Character) is
   begin
      if Idx >= TM_BUF_SIZ then
         return;
      end if;

      case C is
         when ASCII.BS | ASCII.DEL =>
            if Idx > 0 then
               Put_String (BS_Sequence);
               Idx := Idx - 1;
            end if;

         when ' ' =>
            Samv71_Tiny.USART1.Put (' ');
            Idx := Idx + 1;
            Buffer (Idx) := ' ';

         when '.' =>
            Samv71_Tiny.USART1.Put (C);
            Idx := Idx + 1;
            Buffer (Idx) := C;

         when ASCII.CR =>
            if Idx > 0 then
               Dispatch_Cmd;
            else
               Clear_Buffer;
               Show_Prompt;
            end if;

         when '_' =>
            Samv71_Tiny.USART1.Put (C);
            Idx := Idx + 1;
            Buffer (Idx) := C;

         when others =>
            if (C >= 'a' and then C <= 'z')
              or else (C >= 'A' and then C <= 'Z')
              or else (C >= '0' and then C <= '9')
            then
               Samv71_Tiny.USART1.Put (C);
               Idx := Idx + 1;
               Buffer (Idx) := C;
            end if;
      end case;
   end Parse;

   procedure Show_Welcome is
   begin
      Put_String (Welcome);
      Show_Prompt;
   end Show_Welcome;

   task Console;

   task body Console is
      C : Character;
   begin
      loop
         Samv71_Tiny.USART1.Get (C);
         Parse (C);
      end loop;
   end Console;

end Samv71_Tiny.TinyMon;
