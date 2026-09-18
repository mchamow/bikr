#!/bin/zsh
# Runs the UI smoke test with the simulator riding a route through Kraków.
# Usage: scripts/ui-test.sh ["iPhone 17 Pro"] [extra xcodebuild args...]
# Without a device name it picks the newest iPhone simulator available, so the
# same script works on a Mac and on a CI runner.
set -euo pipefail
cd "${0:A:h}/.."

device="${1:-}"
if (( $# > 0 )); then
  shift   # remaining args go to xcodebuild
fi

if [[ -z "$device" ]]; then
  device=$(xcrun simctl list devices available --json | python3 -c '
import json, sys

runtimes = json.load(sys.stdin)["devices"]
def ios_version(runtime):
    digits = [int(part) for part in runtime.split(".")[-1].split("-")[1:] if part.isdigit()]
    return digits or [0]

best = ""
for runtime in sorted((r for r in runtimes if "iOS" in r), key=ios_version, reverse=True):
    phones = [d["name"] for d in runtimes[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if phones:
        best = sorted(phones, key=len)[0]   # the plainest name, e.g. "iPhone 17" over "iPhone 17 Pro Max"
        break
print(best)')
fi

if [[ -z "$device" ]]; then
  print -u2 "No iPhone simulator is available."
  exit 1
fi
echo "Riding on: $device"

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" >/dev/null

destination="platform=iOS Simulator,name=$device"
result="${BIKR_RESULT_BUNDLE:-build/ui-test.xcresult}"
rm -rf "$result"

# Build first. A cold build takes minutes, and the simulated ride must still be
# going when the test starts.
xcodebuild build-for-testing -project Bikr.xcodeproj -scheme Bikr -destination "$destination" "$@"

trap 'xcrun simctl location "$device" clear >/dev/null 2>&1 || true' EXIT
# Ride at 8 m/s (about 29 km/h) with a fix every second.
xcrun simctl location "$device" start --speed 8 --interval 1 \
  50.0614,19.9366 50.0640,19.9450 50.0680,19.9520 50.0720,19.9610 50.0760,19.9700 50.0800,19.9800

xcodebuild test-without-building -project Bikr.xcodeproj -scheme Bikr \
  -destination "$destination" -only-testing:BikrUITests -resultBundlePath "$result" "$@"
