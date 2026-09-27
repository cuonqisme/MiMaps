#!/bin/bash
set -euo pipefail

mkdir -p test-results
simulator_udid="$(bash scripts/ci/simulator_udid.sh)"

xcodebuild \
  -project MiBandNavigator.xcodeproj \
  -scheme MiBandNavigator \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${simulator_udid}" \
  -resultBundlePath test-results/MiBandNavigator.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  clean test
