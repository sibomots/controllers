#!/usr/bin/env bash
#  ============================================================================
#  This file is part of this repository
#
#  Copyright (c) 2025 Jeff Wandling
#  All Rights Reserved.
#
#  Licensed under BSD 3-Clause
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted under the terms of the BSD 3-Clause license.
#  See the LICENSE file for the full text.
#  ============================================================================

printHelp() {
   cat <<EOM
CLEAN                      Repo-wide Build Residue Cleaner

NAME
    clean.sh

SYNOPSIS

    clean.sh [ --help ]
    clean.sh [ -n | --dry-run ] [ -q | --quiet ]

DESCRIPTION

    Cleans every project in this repo by discovering and delegating to
    each one's own build script's "-c | --clean-only" flag -- it does
    NOT hold its own list of build-output paths. Every project here
    already knows how to clean itself (build.sh/buildw.sh -c); this
    script's only job is to find all of them and invoke that flag, so a
    new project dropped in later is picked up automatically, and a
    project's build-output layout only ever needs to be known in one
    place (its own build script).

    Picks build.sh (native) or buildw.sh (git-sdk-64/Windows) depending
    on which shell this is actually running under -- same detection
    every build.sh/buildw.sh pair already does internally. Only scripts
    matching the current platform are invoked; the other variant is
    skipped, not treated as an error.

    Separately, also sweeps for JLinkGDBServer debug-session log files
    (setupw.sh's "-log server.out") anywhere in the repo -- these are a
    debug-session artifact, not a build artifact, so no build script
    knows about them; this is the one thing clean.sh still handles
    directly rather than delegating.

    Never touches anything under a vendor/ directory. Does not touch
    git state (no "git clean") -- only removes what each project's own
    build script already considers its build output.

OPTIONS

    -h | --help       Output this manual page

    -n | --dry-run    Print what would be cleaned, without cleaning it

    -q | --quiet      Suppress each build script's own clean-up output;
                      print only a final summary line

CLEAN                      Repo-wide Build Residue Cleaner
EOM
}

DryRun="no"
Quiet="no"

while [ $# -gt 0 ]
do
   key="$1"
   case $key in
       -n|--dry-run)
       DryRun="yes"
       shift
       ;;
       -q|--quiet)
       Quiet="yes"
       shift
       ;;
       -h|--help)
       printHelp
       exit 0
       ;;
       *)
       echo "Unknown option: $key"
       printHelp
       exit 1
       ;;
   esac
done

set -e

RepoRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Cleaned=0

# Same platform detection every build.sh/buildw.sh pair already does --
# only the variant that would actually run here is invoked.
case "$(uname -s)" in
    MINGW*|MSYS*) BuildScriptName="buildw.sh" ;;
    *)            BuildScriptName="build.sh" ;;
esac

while IFS= read -r -d '' script; do
   dir="$(dirname "$script")"
   Cleaned=$((Cleaned + 1))
   if [ "$DryRun" = "yes" ]; then
      echo "Would run: (cd $dir && bash $BuildScriptName -c)"
   else
      [ "$Quiet" = "yes" ] || echo "Cleaning: $dir"
      if [ "$Quiet" = "yes" ]; then
         (cd "$dir" && bash "$BuildScriptName" -c) > /dev/null
      else
         (cd "$dir" && bash "$BuildScriptName" -c)
      fi
   fi
done < <(find "$RepoRoot" -iname "$BuildScriptName" -not -path "*/vendor/*" -print0 | sort -z)

# JLinkGDBServer debug-session logs, wherever they landed (setupw.sh
# runs with "-log server.out", a relative path -- the file appears in
# whatever directory the server was started from, not a fixed location).
# Not a build.sh concern -- handled directly here, not delegated.
while IFS= read -r -d '' f; do
   Cleaned=$((Cleaned + 1))
   if [ "$DryRun" = "yes" ]; then
      echo "Would remove: $f"
   else
      [ "$Quiet" = "yes" ] || echo "Removing: $f"
      rm -f -- "$f"
   fi
done < <(find "$RepoRoot" -iname "*.out" -not -path "*/vendor/*" -print0 2>/dev/null)

if [ "$DryRun" = "yes" ]; then
   echo "Dry run: $Cleaned item(s) would be cleaned."
else
   echo "Done: $Cleaned item(s) cleaned."
fi
