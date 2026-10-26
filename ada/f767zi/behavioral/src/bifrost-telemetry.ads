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

-- "Telemetry Sink" task (naming carried over loosely from
-- ../../SOFTWARE.md's Main/LCD_Sink/UART_Sink vocabulary): owns the
-- network interface's recurring work end to end, the same ownership
-- pattern Bifrost.LCD_Sink already uses for the LCD -- builds a fresh
-- Slate_Of_State each tick, polls the network interface, and hands
-- the Slate to Bifrost.Telemetry.Sinks.Publish_All.
--
-- No pragma Elaborate_Body here, unlike Bifrost.LCD_Sink's otherwise-
-- identical spec: this spec now declares real types (Slate_Of_State)
-- that Bifrost.Telemetry.Sinks (a child) withs, and the body in turn
-- withs that child for Publish_All -- Elaborate_Body's "body must
-- follow spec immediately, nothing else allowed between" requirement
-- is incompatible with that child-package round trip (confirmed
-- directly: the binder reports a real elaboration circularity with
-- it present). Not needed anyway -- Main's own
-- "with Bifrost.Telemetry; pragma Unreferenced (...)" already pulls
-- this unit's body into the elaboration closure regardless; the
-- pragma only ever controlled elaboration *order* relative to other
-- units, not whether Telemetry_Sink gets activated at all.
with System;
with Interfaces;

package Bifrost.Telemetry is

   -- Declared here (not only in the body) specifically so this
   -- package genuinely requires a body without needing
   -- pragma Elaborate_Body -- see that pragma's own removal note
   -- above. One step above Bifrost.LCD_Sink's lowest priority
   -- (System.Priority'First), still below Bifrost.TinyMon.UART_Sink's
   -- highest: not interactive like the console, so it must not
   -- outrank UART_Sink, but losing/delaying a poll to a cosmetic
   -- display refresh is the wrong trade-off once Bifrost.Net.Eth
   -- becomes real interrupt-adjacent I/O.
   task Telemetry_Sink is
      pragma Priority (System.Priority'First + 1);
   end Telemetry_Sink;

   Slate_Version_Current : constant Interfaces.Unsigned_8 := 1;

   -- Hypothesized fields, explicitly placeholders pending real
   -- requirements -- "slate of state" was asked for before any real
   -- metric set was defined. Slate_Version makes a future shape
   -- change (adding/removing/retyping a field) self-describing on the
   -- wire to whatever's listening; bump Slate_Version_Current
   -- whenever that happens.
   --
   -- No protected object or Atomic field guards this type: it never
   -- actually crosses a task boundary -- Telemetry_Sink is both the
   -- only builder and the only reader of any given Slate_Of_State
   -- value, built fresh as a local variable each tick and passed by
   -- value straight into Publish_All. The moment a *different* task
   -- needs to feed a field (a real ADC sampled by its own task, a
   -- console command that changes User_Tag at runtime), promote
   -- exactly that field to the Live_Counter-style Atomic scalar
   -- pattern Bifrost.TinyMon/Bifrost.LCD_Sink already share, or wrap
   -- the whole record in a protected object (mirroring
   -- Bifrost.UART's Controller) if several fields must be snapshotted
   -- together atomically.
   type Slate_Of_State is record
      Slate_Version : Interfaces.Unsigned_8  := Slate_Version_Current;
      Sample_Seq    : Interfaces.Unsigned_32 := 0;  -- free-running, wraps
      Uptime_Ms     : Interfaces.Unsigned_32 := 0;  -- since Telemetry_Sink's first tick
      ADC_Channel_0 : Interfaces.Unsigned_16 := 0;  -- PLACEHOLDER, not a real conversion
      ADC_Channel_1 : Interfaces.Unsigned_16 := 0;  -- PLACEHOLDER, ditto
      User_Tag      : String (1 .. 8) := "F767ZI0 ";  -- PLACEHOLDER, fixed width
   end record;

end Bifrost.Telemetry;
