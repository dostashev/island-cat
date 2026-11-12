#!/usr/bin/env bash
# Runs the tests. Xcode finds swift-testing on its own; the Command Line
# Tools keep it out of the default search path.
set -euo pipefail
cd "$(dirname "$0")/.."
flags=()
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [[ -d "$frameworks/Testing.framework" ]]; then
  flags=(-Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
  lib="$(xcode-select -p)/Library/Developer/usr/lib"
  [[ -d "$lib" ]] && flags+=(-Xlinker -rpath -Xlinker "$lib")
fi
swift test "${flags[@]}" "$@"
