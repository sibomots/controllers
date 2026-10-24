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

with System;
with Bifrost.UART;
with Bifrost.LCD_String;
with Bifrost.LCD_Config;

package body Bifrost.TinyMon is

   Buf_Size : constant := 64;

   Prompt : constant String := ASCII.CR & ASCII.LF & "TinyMon> ";

   Platform_Desc : constant String := "NUCLEO-F767ZI (STM32F767ZI)";

   -- Hand-edit this on each release. Deliberately not derived from the
   -- git commit SHA -- a build can't know the SHA of the commit that
   -- will contain it, and a plain string avoids that chicken-and-egg
   -- problem entirely.
   Software_Version : constant String := "0.1.0";

   License_Text : constant String :=
     "Copyright (c) 2025 Jeff Wandling. All rights reserved. | " &
     "BSD 3-Clause License";

   Welcome : constant String :=
     ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF &
     "This is TinyMon" & ASCII.CR & ASCII.LF &
     Platform_Desc & ASCII.CR & ASCII.LF &
     "Version " & Software_Version & ASCII.CR & ASCII.LF &
     License_Text & ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF &
     "Type 'help' for more information." & ASCII.CR & ASCII.LF &
     ASCII.CR & ASCII.LF;

   Help_Text : constant String :=
     ASCII.CR & ASCII.LF & ASCII.LF &
     Platform_Desc & ASCII.CR & ASCII.LF &
     "Version " & Software_Version & ASCII.CR & ASCII.LF &
     License_Text & ASCII.CR & ASCII.LF & ASCII.LF &
     "Available commands:" & ASCII.CR & ASCII.LF &
     "help" & ASCII.CR & ASCII.LF &
     "count" & ASCII.CR & ASCII.LF &
     "license" & ASCII.CR & ASCII.LF;

   License_Reply : constant String :=
     ASCII.CR & ASCII.LF & License_Text & ASCII.CR & ASCII.LF;

   Unknown_Text : constant String :=
     ASCII.CR & ASCII.LF & "unknown command" & ASCII.CR & ASCII.LF;

   BS_Sequence : constant String := ASCII.BS & " " & ASCII.BS;
   CRLF        : constant String := ASCII.CR & ASCII.LF;

   Buffer : String (1 .. Buf_Size);
   Idx    : Natural := 0;

   -- Shared between Bifrost.LCD_Sink's task (the only writer, via
   -- Set_Counter) and UART_Sink below (the only reader, via Show_Count).
   -- A scalar with exactly one writer task and one reader task needs no
   -- protected object -- Atomic (not merely Volatile) is the right
   -- aspect for this specific contract: it additionally guarantees the
   -- read/write themselves are indivisible, which Volatile alone does
   -- not promise, so UART_Sink can never observe a torn value if a
   -- 32-bit Natural write is ever not naturally atomic on some future
   -- target. Same reasoning class ../../f722ze-tiny/lowlevel/src/
   -- bifrost-uart.adb used to justify its lock-free ring buffer indices
   -- needing no protected object, applied here to a plain scalar
   -- instead of a ring.
   Live_Counter : Natural := 0 with Atomic;

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

   procedure Show_License is
   begin
      Put_String (License_Reply);
   end Show_License;

   procedure Show_Count is
      Count_Buf : String (1 .. Bifrost.LCD_Config.LCD_Max_Col);
      Length    : Natural;
      Snapshot  : Natural := Live_Counter;
   begin
      -- Format takes Counter as "in out" (it may reset it to 0 on
      -- rollover) -- Snapshot is a local copy so that reset never writes
      -- back into Live_Counter itself; LCD_Sink owns that value and
      -- will naturally resync it on its own next tick regardless.
      Bifrost.LCD_String.Format (Snapshot, Count_Buf, Length);
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
      elsif Line = "license" then
         Show_License;
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

   -- The "UART Sink" task named in ../../SOFTWARE.md's planned
   -- architecture. Library-level, so Ravenscar activates it
   -- automatically during elaboration, before Main's own body runs --
   -- same activation order ada/samv71-tiny's Console task relies on.
   -- Runs at a higher priority than Bifrost.LCD_Sink's periodic task
   -- (see that package): console responsiveness to a byte that's
   -- already arrived matters more than a cosmetic display refresh
   -- being exactly on schedule.
   task UART_Sink is
      pragma Priority (System.Priority'Last);
   end UART_Sink;

   task body UART_Sink is
      C : Character;
   begin
      loop
         Bifrost.UART.Get (C);
         Parse (C);
      end loop;
   end UART_Sink;

end Bifrost.TinyMon;
