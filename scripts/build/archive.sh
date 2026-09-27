#!/bin/bash
set -euo pipefail

mode="${1:-unsigned}"
case "${mode}" in
  unsigned|signed) ;;
  *)
    echo "Usage: $0 [unsigned|signed]" >&2
    exit 64
    ;;
esac

archive_path="${ARCHIVE_PATH:-artifacts/release/MiBandNavigator.xcarchive}"
build_number="${BUILD_NUMBER:-1}"
marketing_version="${MARKETING_VERSION:-0.1.0}"
bundle_id="${BUNDLE_ID:-com.example.mibandnavigator}"
archive_log="${ARCHIVE_LOG:-artifacts/release/archive.log}"

mkdir -p "$(dirname "${archive_path}")" "$(dirname "${archive_log}")"

build_settings=(
  "CURRENT_PROJECT_VERSION=${build_number}"
  "MARKETING_VERSION=${marketing_version}"
  "PRODUCT_BUNDLE_IDENTIFIER=${bundle_id}"
)

if [[ "${mode}" == "signed" ]]; then
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required for a signed archive}"
  : "${PROVISIONING_PROFILE_SPECIFIER:?PROVISIONING_PROFILE_SPECIFIER is required for a signed archive}"
  : "${SIGNING_KEYCHAIN_PATH:?SIGNING_KEYCHAIN_PATH is required for a signed archive}"
  : "${GOOGLE_MAPS_API_KEY:?GOOGLE_MAPS_API_KEY is required for a release archive}"

  build_settings+=(
    "DEVELOPMENT_TEAM=${APPLE_TEAM_ID}"
    "CODE_SIGN_STYLE=Manual"
    "CODE_SIGN_IDENTITY=Apple Distribution"
    "PROVISIONING_PROFILE_SPECIFIER=${PROVISIONING_PROFILE_SPECIFIER}"
    "OTHER_CODE_SIGN_FLAGS=--keychain ${SIGNING_KEYCHAIN_PATH}"
  )
else
  build_settings+=(
    "CODE_SIGNING_ALLOWED=NO"
    "CODE_SIGNING_REQUIRED=NO"
    "CODE_SIGN_IDENTITY="
    "DEVELOPMENT_TEAM="
  )
fi

echo "Creating ${mode} Release archive at ${archive_path}"
xcodebuild \
  -project MiBandNavigator.xcodeproj \
  -scheme MiBandNavigator \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${archive_path}" \
  "${build_settings[@]}" \
  clean archive 2>&1 | tee "${archive_log}"

if [[ ! -d "${archive_path}" ]]; then
  echo "Archive was not created at ${archive_path}" >&2
  exit 1
fi

echo "Archive created successfully."
