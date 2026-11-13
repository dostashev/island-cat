#!/usr/bin/env bash
# Builds the release zip for the version in Resources/Info.plist and points
# Casks/island-cat.rb at it. Then commit the cask and publish the zip as
# that version's GitHub release:
#   gh release create v<version> "build/Island-Cat-<version>.zip"
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
# Ad hoc, not the local identity: a self-signed certificate means nothing
# on anyone else's Mac.
ISLAND_CAT_SIGN_IDENTITY=- scripts/bundle.sh
zip="build/Island-Cat-$version.zip"
rm -f "$zip"
ditto -c -k --sequesterRsrc --keepParent "build/Island Cat.app" "$zip"
sha=$(shasum -a 256 "$zip" | cut -d' ' -f1)
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
  Casks/island-cat.rb
echo "Built $zip ($sha)"
