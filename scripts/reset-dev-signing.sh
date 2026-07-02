#!/usr/bin/env bash
# reset-dev-signing.sh
#
# Restores project.pbxproj to the committed openHAB Foundation signing settings.
# Run this before pushing or creating a PR, or before a git pull that touches
# the project file.

set -euo pipefail

PROJECT="openHAB.xcodeproj/project.pbxproj"

git update-index --no-assume-unchanged "$PROJECT"
git checkout -- "$PROJECT"
rm -f "$PROJECT.bak"

echo "Signing restored to openHAB Foundation settings."
