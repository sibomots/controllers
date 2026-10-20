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

with Bifrost.UART;
with Bifrost.LCD_String;
with Bifrost.LCD_Config;

package body Bifrost.TinyMon is

   Buf_Size : constant := 64;

   Prompt : constant String := ASCII.CR & ASCII.LF & "TinyMon> ";

   Welcome : constant String :=
     ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF &
     "This is TinyMon" & ASCII.CR & ASCII.LF &
     "Type 'help' for more information." & ASCII.CR & ASCII.LF &
     ASCII.CR & ASCII.LF;

   Help_Text : constant String :=
     ASCII.CR & ASCII.LF & ASCII.LF &
     "Available commands:" & ASCII.CR & ASCII.LF &
     "help" & ASCII.CR & ASCII.LF &
     "count" & ASCII.CR & ASCII.LF;

   Unknown_Text : constant String :=
     ASCII.CR & ASCII.LF & "unknown command" & ASCII.CR & ASCII.LF;

   BS_Sequence : constant String := ASCII.BS & " " & ASCII.BS;
   CRLF        : constant String := ASCII.CR & ASCII.LF;

   Buffer : String (1 .. Buf_Size);
   Idx    : Natural := 0;

   -- A mirror of main.adb's own Counter, kept current via Set_Counter
   -- each loop iteration -- not the literal variable (that one's local
   -- to the Main procedure). One accepted consequence: Bifrost.LCD_String
   -- .Format resets its Counter argument to 0 on rollover (at
   -- Bifrost.LCD_Config.LCD_Max_Num); calling it here on Live_Counter
   -- only resets this mirror, not main.adb's real Counter. Harmless --
   -- the next main-loop iteration resyncs this mirror anyway, and
   -- actually reaching LCD_Max_Num (99,999,999) takes a very long time
   -- at this increment rate.
   Live_Counter : Natural := 0;

   procedure Put_String (S : String) is
   begin
      for C of S loop
         Bifrost.UART.Put (C);
      end loop;
   end Put_String;

   procedure Show_Prompt is
   begin
      Put_String (Prompt);
   end Show_Prompt;

   procedure Show_Help is
   begin
      Put_String (Help_Text);
   end Show_Help;

   procedure Show_Count is
      Count_Buf : String (1 .. Bifrost.LCD_Config.LCD_Max_Col);
      Length    : Natural;
   begin
      Bifrost.LCD_String.Format (Live_Counter, Count_Buf, Length);
      Put_String (CRLF);
      Put_String (Count_Buf (1 .. Length));
      Put_String (CRLF);
   end Show_Count;

   procedure Clear_Buffer is
   begin
      Idx := 0;
   end Clear_Buffer;

   procedure Dispatch_Cmd is
      Line : constant String := Buffer (1 .. Idx);
   begin
      if Line = "help" then
         Show_Help;
      elsif Line = "count" then
         Show_Count;
      else
         Put_String (Unknown_Text);
      end if;

      Clear_Buffer;
      Show_Prompt;
   end Dispatch_Cmd;

   procedure Parse (C : Character) is
   begin
      if Idx >= Buf_Size then
         return;
      end if;

      case C is
         when ASCII.BS | ASCII.DEL =>
            if Idx > 0 then
               Put_String (BS_Sequence);
               Idx := Idx - 1;
            end if;

         when ASCII.CR =>
            if Idx > 0 then
               Dispatch_Cmd;
            else
               Clear_Buffer;
               Show_Prompt;
            end if;

         when others =>
            if (C >= 'a' and then C <= 'z')
              or else (C >= 'A' and then C <= 'Z')
              or else (C >= '0' and then C <= '9')
            then
               Bifrost.UART.Put (C);
               Idx := Idx + 1;
               Buffer (Idx) := C;
            end if;
      end case;
   end Parse;

   procedure Set_Counter (Value : Natural) is
   begin
      Live_Counter := Value;
   end Set_Counter;

   procedure Show_Welcome is
   begin
      Put_String (Welcome);
      Show_Prompt;
   end Show_Welcome;

end Bifrost.TinyMon;
