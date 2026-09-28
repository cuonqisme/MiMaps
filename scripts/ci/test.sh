#!/bin/bash
set -euo pipefail

mkdir -p test-results
simulator_udid="$(bash scripts/ci/simulator_udid.sh)"

xcodebuild \
  -project MiMaps.xcodeproj \
  -scheme MiMaps \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${simulator_udid}" \
  -resultBundlePath test-results/MiMaps.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  clean test
