#!/usr/bin/env bash
# Captures the README screenshots of the DevToolsDemo example app on an iPhone simulator.
#
# The script builds and installs the app, launches it with launch arguments that send the sample
# requests (to api.github.com and postman-echo.com, so it needs a network connection) and open one
# screen, and takes a simulator screenshot in light and dark appearance. The images show real
# requests recorded by NetworkCapture, so values such as durations and sizes differ between runs.
#
# Usage: scripts/capture-screens.sh [simulator name or UDID]
# Without an argument it uses a simulator named "iPhone 17 Pro".
# Output: docs/images/<screen>-light.png and docs/images/<screen>-dark.png for the screens
# network, request, logs and device, each scaled to half the simulator's width.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-iPhone 17 Pro}"
bundle_id="io.github.muhittincamdali.DevToolsDemo"
output_dir="$repo_root/docs/images"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$output_dir"

destination="platform=iOS Simulator,name=$device"
if [[ "$device" =~ ^[0-9A-F-]{36}$ ]]; then
  destination="platform=iOS Simulator,id=$device"
fi
echo "Building DevToolsDemo for '$device'"
xcodebuild build \
  -project "$repo_root/Examples/DevToolsDemo/DevToolsDemo.xcodeproj" \
  -scheme DevToolsDemo \
  -destination "$destination" \
  -derivedDataPath "$build_dir" \
  -quiet
app="$(find "$build_dir/Build/Products" -maxdepth 2 -name 'DevToolsDemo.app' -path '*iphonesimulator*' | head -1)"

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl install "$device" "$app"
# A fixed clock and full bars keep the status bar the same in every image.
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null

# The first launch after an install is slow; launch once before taking any screenshot.
xcrun simctl launch --terminate-running-process "$device" "$bundle_id" >/dev/null
sleep 5

capture() {
  local name="$1"
  shift
  for appearance in light dark; do
    xcrun simctl ui "$device" appearance "$appearance"
    # English text and number formats, whatever the region the simulator inherited from the Mac.
    xcrun simctl launch --terminate-running-process "$device" "$bundle_id" -run-requests "$@" \
      -AppleLanguages "(en)" -AppleLocale en_US >/dev/null
    sleep 14 # the seven requests, then the sheet animation
    local file="$output_dir/$name-$appearance.png"
    xcrun simctl io "$device" screenshot --type=png "$file" >/dev/null 2>&1
    sips --resampleWidth "$(( $(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}') / 2 ))" "$file" >/dev/null
    echo "$file"
  done
}

capture network -console network
capture request -entry "Sign in"
capture logs -console logs
capture device -console device

xcrun simctl status_bar "$device" clear
