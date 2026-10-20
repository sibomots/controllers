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

-- Root namespace for the Bifrost application. Deliberately empty -- it
-- exists only so child packages (Bifrost.UART, Bifrost.Delay_Util, ...)
-- have a common parent, same role the "bifrost" prefix plays informally
-- in the C tree's naming.
package Bifrost is
end Bifrost;
