#!/bin/zsh
# Runs the UI smoke test with the simulator riding a route through Kraków.
set -euo pipefail
cd "${0:A:h}/.."

device="${1:-iPhone 18 Pro}"
(( $# > 0 )) && shift   # remaining args go to xcodebuild
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" >/dev/null

# Ride at 8 m/s (about 29 km/h) with a fix every second, until cleared.
xcrun simctl location "$device" start --speed 8 --interval 1 \
  50.0614,19.9366 50.0640,19.9450 50.0680,19.9520 50.0720,19.9610 50.0760,19.9700 50.0800,19.9800

trap 'xcrun simctl location "$device" clear >/dev/null 2>&1 || true' EXIT
# Stop the simulated ride after the test's riding phase; leaving it running
# has made xcodebuild hang during teardown.
( sleep 90; xcrun simctl location "$device" clear >/dev/null 2>&1 || true ) &

xcodebuild test -project Bikr.xcodeproj -scheme Bikr \
  -destination "platform=iOS Simulator,name=$device" \
  -only-testing:BikrUITests "$@"
