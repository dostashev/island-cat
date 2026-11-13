#!/usr/bin/env bash
# Redraws Resources/AppIcon.icns from scripts/make-icon.swift and the menu
# bar icon's drawing in Sources/IslandCat/CatIcon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Top-level code has to be in a file called main.swift.
cp scripts/make-icon.swift "$work/main.swift"
swiftc -o "$work/make-icon" Sources/IslandCat/CatIcon.swift "$work/main.swift"
"$work/make-icon" "$work/AppIcon.iconset"
iconutil -c icns -o Resources/AppIcon.icns "$work/AppIcon.iconset"
echo "Wrote Resources/AppIcon.icns"
