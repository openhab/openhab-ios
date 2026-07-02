#!/usr/bin/env bash
# setup-dev-signing.sh
#
# Patches project.pbxproj to use your personal Apple Developer team for local
# Debug builds. Run once after cloning, and again after any pull that touches
# the project file.
#
# Usage:
#   scripts/setup-dev-signing.sh           # auto-detects team ID from Keychain
#   scripts/setup-dev-signing.sh ABCDE12345  # explicit team ID

set -euo pipefail

OPENHAB_TEAM="PBAPXHRAM9"
PROJECT="openHAB.xcodeproj/project.pbxproj"

# ── Team ID resolution ───────────────────────────────────────────────────────

TEAM_ID="${1:-}"

if [ -z "$TEAM_ID" ]; then
    TEAM_ID=$(
        security find-identity -v -p codesigning 2>/dev/null \
            | grep "Apple Development" \
            | grep -oE '\([A-Z0-9]{10}\)' \
            | head -1 \
            | tr -d '()'
    )
fi

if [ -z "$TEAM_ID" ]; then
    echo "error: no Apple Development certificate found in Keychain." >&2
    echo "  Either install a development certificate or pass your Team ID explicitly:" >&2
    echo "  $0 <TEAM_ID>" >&2
    exit 1
fi

if [ "$TEAM_ID" = "$OPENHAB_TEAM" ]; then
    echo "Already using the openHAB Foundation team — nothing to do."
    exit 0
fi

# ── Patch ────────────────────────────────────────────────────────────────────

cp "$PROJECT" "$PROJECT.bak"
sed -i '' "s/$OPENHAB_TEAM/$TEAM_ID/g" "$PROJECT"

# Tell git not to flag the project file as locally modified.
# Note: git pull/rebase will still update the file — re-run this script afterwards.
git update-index --assume-unchanged "$PROJECT"

echo "Patched $PROJECT"
echo "  Replaced team $OPENHAB_TEAM → $TEAM_ID"
echo "  A backup was saved to $PROJECT.bak"
echo ""
echo "To undo at any time:  scripts/reset-dev-signing.sh"
echo "After git pull:       re-run this script if the project file changed upstream"
