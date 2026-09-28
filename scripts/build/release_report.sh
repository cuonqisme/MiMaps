#!/bin/bash
set -euo pipefail

release_dir="${RELEASE_DIR:-artifacts/release}"
archive_path="${ARCHIVE_PATH:-${release_dir}/MiMaps.xcarchive}"
export_path="${EXPORT_PATH:-${release_dir}/export}"
report_path="${release_dir}/RELEASE_REPORT.md"
result_bundle="${TEST_RESULT_BUNDLE:-test-results/MiMaps.xcresult}"

mkdir -p "${release_dir}"

commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
xcode_version="$(xcodebuild -version 2>/dev/null | paste -sd ' ' - || echo unavailable)"
swift_version="$(swift --version 2>/dev/null | head -n 1 || echo unavailable)"
macos_version="$(sw_vers -productVersion 2>/dev/null || echo unavailable)"

test_result="FAILED OR NOT RUN"
test_count="unknown"
if [[ -d "${result_bundle}" ]]; then
  test_result="PASSED"
  summary_json="$(xcrun xcresulttool get test-results summary --path "${result_bundle}" --format json 2>/dev/null || true)"
  if command -v jq >/dev/null 2>&1 && [[ -n "${summary_json}" ]]; then
    test_count="$(printf '%s' "${summary_json}" | jq -r '.totalTestCount // "unknown"')"
  fi
fi

archive_result="FAILED OR NOT RUN"
if [[ -d "${archive_path}" ]]; then
  archive_result="PASSED"
fi

ipa_result="NOT PRODUCED"
ipa_name="None"
ipa_checksum="None"
ipa_path=""
if [[ -d "${export_path}" ]]; then
  ipa_path="$(find "${export_path}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
fi
if [[ -n "${ipa_path}" ]]; then
  ipa_result="PASSED"
  ipa_name="$(basename "${ipa_path}")"
  ipa_checksum="$(shasum -a 256 "${ipa_path}" | awk '{print $1}')"
fi

testflight_result="${TESTFLIGHT_RESULT:-NOT RUN}"
if [[ -f "${release_dir}/testflight-upload.txt" ]]; then
  testflight_result="UPLOAD ACCEPTED FOR PROCESSING"
fi

cat > "${report_path}" <<REPORT
# MiMaps release report

| Field | Result |
|---|---|
| Application version | ${MARKETING_VERSION:-1.0.0} |
| Build number | ${BUILD_NUMBER:-unknown} |
| Git commit | ${commit} |
| Xcode | ${xcode_version} |
| Swift | ${swift_version} |
| macOS runner | ${macos_version} |
| iOS deployment target | 16.0 |
| Map provider | Apple MapKit (native) |
| Third-party map API key | Not required |
| Build result | ${archive_result} |
| Unit test result | ${test_result} |
| Number of tests | ${test_count} |
| Archive result | ${archive_result} |
| IPA result | ${ipa_result} |
| IPA artifact name | ${ipa_name} |
| IPA SHA-256 | ${ipa_checksum} |
| TestFlight result | ${testflight_result} |
| Signing method | ${SIGNING_RESULT:-Not configured} |
| Physical iPhone tests | PENDING |
| Mi Band symbols tested | Basic arrows verified on physical Mi Band 9; fallback glyphs used for unsupported symbols |
| MapKit navigation tests | Search/route provider compiles; maneuver classifier and pipeline unit-tested |

## Verification boundaries

- Apple MapKit search and routing require network access and physical-device verification for live GPS behavior.
- Apple signing and IPA export require a matching Apple Distribution certificate, provisioning profile, Team ID, and Bundle ID.
- TestFlight acceptance is not claimed by this release workflow.
- iPhone, background GPS, Mi Fitness, Mi Band vibration, rendering, Unicode symbols, and road behavior remain pending physical hardware tests.
REPORT

echo "Release report written to ${report_path}"
