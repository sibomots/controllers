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

-- Direct port of tinymon/include/tinymon.h + tinymon/src/tinymon.c --
-- the console line editor, command dispatch, and status/hex-dump
-- output.
--
-- Structural change from the C version: there, byte arrival is
-- *polled* -- GatherInputs (called every iteration of main's
-- superloop) checks "if (tm_input > 0) parse();". Here, a library-level
-- task (declared in the body) blocks on Samv71_Tiny.USART1.Get, which
-- is a real Ravenscar protected entry -- genuinely event-driven, not
-- polled, which is exactly the improvement Phase 3's tasking design
-- was building toward. render_pins()/print_user_messages()/
-- build_user_messages() were only split the way they were because the
-- old main.c superloop had separate Calculate/RenderOutput phases to
-- put them in (confirmed by reading main.c -- every *other* function
-- in those phases, like normalize_data/render_cross_talk, is an empty
-- no-op stub; nothing real ever used that separation). With no
-- superloop here, Dispatch_Cmd below just does
-- Handle_Command -> Render_Pins -> show the result, in one place.
package Samv71_Tiny.TinyMon is

   -- Shows the welcome banner and the first prompt. Call once from
   -- Main, after Samv71_Tiny.USART1.Initialize -- not automatically at
   -- elaboration, because the console task below (which starts
   -- automatically) would otherwise race USART1's own hardware bring-up.
   procedure Show_Welcome;

end Samv71_Tiny.TinyMon;
