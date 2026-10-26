#!/usr/bin/env bash
#  ============================================================================
#  This file is part of Bifrost
#
#  Copyright (c) 2025 Jeff Wandling
#  All Rights Reserved.
#
#  Licensed under BSD 3-Clause
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted under the terms of the BSD 3-Clause license.
#  See the LICENSE file for the full text.
#  ============================================================================
#
# Reads net.conf (KEY=VALUE, one per line) and emits two generated,
# gitignored files from it -- a single source of truth read by both
# languages natively, rather than reaching across the Ada/C boundary
# for these five constants:
#   lowlevel/src/bifrost-net-config.ads  (Ada: Dest_IP/Dest_Port, used
#     by the Phase D UDP sink)
#   lowlevel/src/bifrost_net_config.h    (C: Our_MAC/Our_IP/Our_Port,
#     used by ethernetif.c's interface bring-up)
#
# Usage: bash gen_net_config.sh net.conf
#
# Deliberately does NOT range-validate octets/ports itself -- a
# malformed value (e.g. an octet > 255) fails to compile in the
# *generated* files with a precise compiler error (Ada range check /
# C -Woverflow), since both sides declare octets as 8-bit-range types.
# Validation for free from the type system, not an oversight.

set -e

if [ $# -ne 1 ]; then
    echo "Usage: bash gen_net_config.sh <net.conf>" >&2
    exit 1
fi

CONF="$1"
if [ ! -f "$CONF" ]; then
    echo "gen_net_config.sh: $CONF not found" >&2
    exit 1
fi

OUR_MAC=""
OUR_IP=""
OUR_PORT=""
DEST_IP=""
DEST_PORT=""

while IFS= read -r line || [ -n "$line" ]; do
    # Strip a possible trailing \r (Windows-edited file) and comments/blanks.
    line="${line%$'\r'}"
    case "$line" in
        ''|'#'*) continue ;;
    esac
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
        OUR_MAC)    OUR_MAC="$val" ;;
        OUR_IP)     OUR_IP="$val" ;;
        OUR_PORT)   OUR_PORT="$val" ;;
        DEST_IP)    DEST_IP="$val" ;;
        DEST_PORT)  DEST_PORT="$val" ;;
        *)
            echo "gen_net_config.sh: unrecognized key in $CONF: $key" >&2
            exit 1
            ;;
    esac
done < "$CONF"

for name in OUR_MAC OUR_IP OUR_PORT DEST_IP DEST_PORT; do
    eval "val=\$$name"
    if [ -z "$val" ]; then
        echo "gen_net_config.sh: missing required key in $CONF: $name" >&2
        exit 1
    fi
done

# Split "02:00:00:00:00:01" into six "16#xx#" Ada literals / "0x02"-style C literals.
IFS=':' read -r M0 M1 M2 M3 M4 M5 <<< "$OUR_MAC"
# Split "192.168.1.50" into four decimal octets.
IFS='.' read -r OIP0 OIP1 OIP2 OIP3 <<< "$OUR_IP"
IFS='.' read -r DIP0 DIP1 DIP2 DIP3 <<< "$DEST_IP"

OUT_DIR="$(dirname "$0")/lowlevel/src"

cat > "$OUT_DIR/bifrost-net-config.ads" <<EOF
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

-- GENERATED FILE -- do not hand-edit. Source of truth: ../../net.conf,
-- via ../../gen_net_config.sh. Regenerated on every build.
package Bifrost.Net.Config is

   Our_MAC   : constant Bifrost.Net.Types.MAC_Address :=
     (16#$M0#, 16#$M1#, 16#$M2#, 16#$M3#, 16#$M4#, 16#$M5#);
   Our_IP    : constant Bifrost.Net.Types.IPv4_Address :=
     ($OIP0, $OIP1, $OIP2, $OIP3);
   Our_Port  : constant := $OUR_PORT;

   Dest_IP   : constant Bifrost.Net.Types.IPv4_Address :=
     ($DIP0, $DIP1, $DIP2, $DIP3);
   Dest_Port : constant := $DEST_PORT;

end Bifrost.Net.Config;
EOF

cat > "$OUT_DIR/bifrost_net_config.h" <<EOF
/* ============================================================================
 * This file is part of Bifrost
 *
 * Copyright (c) 2025 Jeff Wandling
 * All Rights Reserved.
 *
 * Licensed under BSD 3-Clause
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted under the terms of the BSD 3-Clause license.
 * See the LICENSE file for the full text.
 * ============================================================================ */

/* GENERATED FILE -- do not hand-edit. Source of truth: ../../net.conf,
 * via ../../gen_net_config.sh. Regenerated on every build. */
#ifndef BIFROST_NET_CONFIG_H
#define BIFROST_NET_CONFIG_H

#define BIFROST_NET_OUR_MAC0 0x${M0}U
#define BIFROST_NET_OUR_MAC1 0x${M1}U
#define BIFROST_NET_OUR_MAC2 0x${M2}U
#define BIFROST_NET_OUR_MAC3 0x${M3}U
#define BIFROST_NET_OUR_MAC4 0x${M4}U
#define BIFROST_NET_OUR_MAC5 0x${M5}U

#define BIFROST_NET_OUR_IP0 ${OIP0}U
#define BIFROST_NET_OUR_IP1 ${OIP1}U
#define BIFROST_NET_OUR_IP2 ${OIP2}U
#define BIFROST_NET_OUR_IP3 ${OIP3}U

#define BIFROST_NET_OUR_PORT ${OUR_PORT}U

#define BIFROST_NET_DEST_IP0 ${DIP0}U
#define BIFROST_NET_DEST_IP1 ${DIP1}U
#define BIFROST_NET_DEST_IP2 ${DIP2}U
#define BIFROST_NET_DEST_IP3 ${DIP3}U

#define BIFROST_NET_DEST_PORT ${DEST_PORT}U

#endif /* BIFROST_NET_CONFIG_H */
EOF

echo "gen_net_config.sh: wrote $OUT_DIR/bifrost-net-config.ads and bifrost_net_config.h"
