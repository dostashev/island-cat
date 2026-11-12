#!/usr/bin/env bash
# Builds build/Island Cat.app, a universal release build signed ad hoc.
# Usage: scripts/bundle.sh [--install]   (--install copies it to /Applications and opens it)
set -euo pipefail
cd "$(dirname "$0")/.."

# One build per architecture, joined with lipo: a single multi-arch
# `swift build` needs Xcode, and this works with the Command Line Tools.
slices=()
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx14.0"
  slices+=("$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)/IslandCat")
done

app="build/Island Cat.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
lipo -create -output "$app/Contents/MacOS/IslandCat" "${slices[@]}"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  osascript -e 'quit app "Island Cat"' 2>/dev/null || true
  rm -rf "/Applications/Island Cat.app"
  cp -R "$app" /Applications/
  open "/Applications/Island Cat.app"
  echo "Installed /Applications/Island Cat.app"
fi
