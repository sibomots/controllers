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

-- The sink "registry": a fixed, hand-edited sequence of Publish calls,
-- not a tagged-type Sink'Class with dynamic dispatch. Weighed
-- directly, not by default: nothing in this codebase uses a tagged
-- type anywhere, and this would be a first on the single riskiest
-- runtime tier in the repo (light-tasking-stm32f769disco). This
-- static approach fully satisfies "trivial to add a sink" with zero
-- runtime-support risk -- every sink package independently exposes
-- the identical profile "procedure Publish (Slate : Slate_Of_State)",
-- a compiler-checked, structurally identical contract at every call
-- site, just resolved by the linker rather than a vtable. Revisit
-- tagged dispatch only if a real need for *runtime-selectable* sinks
-- (toggle one on/off without a rebuild) ever appears -- this
-- mechanism can't do that, dispatch could.
package Bifrost.Telemetry.Sinks is

   procedure Publish_All (Slate : Bifrost.Telemetry.Slate_Of_State);

end Bifrost.Telemetry.Sinks;
