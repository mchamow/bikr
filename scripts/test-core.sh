#!/bin/zsh
# Runs the BikrCore unit tests. Works with full Xcode or with only the
# Command Line Tools (which need Swift Testing's location spelled out).
set -euo pipefail
cd "${0:A:h}/../Packages/BikrCore"

extra=()
if [[ "${DEVELOPER_DIR:-$(xcode-select -p)}" == */CommandLineTools ]]; then
  fw=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  lib=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
  extra=(-Xswiftc -F -Xswiftc $fw -Xlinker -F -Xlinker $fw
         -Xlinker -rpath -Xlinker $fw -Xlinker -rpath -Xlinker $lib)
fi
swift test "${extra[@]}" "$@"
