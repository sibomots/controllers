-- ============================================================================
-- Crosby -- NUCLEO-F767ZI bare-metal Ada minimal example.
--
-- Copyright (c) 2026 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================

-- User LED LD1 (PB0), via direct register access. See DESIGN.md for
-- the board documentation that pins down PB0 as the correct wiring.
package Crosby.LED is

   procedure Initialize;

   procedure On;
   procedure Off;

end Crosby.LED;
