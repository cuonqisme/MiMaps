#!/bin/bash
set -euo pipefail

archive_path="${ARCHIVE_PATH:-artifacts/release/MiMaps.xcarchive}"
export_path="${EXPORT_PATH:-artifacts/release/export}"
export_method="${EXPORT_METHOD:-app-store-connect}"
export_options_path="${EXPORT_OPTIONS_PATH:-artifacts/release/ExportOptions.plist}"
export_log="${EXPORT_LOG:-artifacts/release/export.log}"

: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${PROVISIONING_PROFILE_SPECIFIER:?PROVISIONING_PROFILE_SPECIFIER is required}"

case "${export_method}" in
  app-store-connect|release-testing|debugging) ;;
  *)
    echo "Unsupported EXPORT_METHOD: ${export_method}" >&2
    exit 64
    ;;
esac

if [[ ! -d "${archive_path}" ]]; then
  echo "Archive does not exist: ${archive_path}" >&2
  exit 1
fi

mkdir -p "${export_path}" "$(dirname "${export_options_path}")" "$(dirname "${export_log}")"

cat > "${export_options_path}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>${export_method}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_ID}</key>
    <string>${PROVISIONING_PROFILE_SPECIFIER}</string>
  </dict>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

plutil -lint "${export_options_path}"
xcodebuild \
  -exportArchive \
  -archivePath "${archive_path}" \
  -exportPath "${export_path}" \
  -exportOptionsPlist "${export_options_path}" 2>&1 | tee "${export_log}"

ipa_path="$(find "${export_path}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
if [[ -z "${ipa_path}" ]]; then
  echo "xcodebuild completed without producing an IPA in ${export_path}" >&2
  exit 1
fi

checksum_path="${ipa_path}.sha256"
shasum -a 256 "${ipa_path}" > "${checksum_path}"
echo "IPA created: ${ipa_path}"
echo "Checksum: ${checksum_path}"
