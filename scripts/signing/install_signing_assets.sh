#!/bin/bash
set -euo pipefail

: "${BUILD_CERTIFICATE_BASE64:?BUILD_CERTIFICATE_BASE64 secret is required}"
: "${P12_PASSWORD:?P12_PASSWORD secret is required}"
: "${PROVISIONING_PROFILE_BASE64:?PROVISIONING_PROFILE_BASE64 secret is required}"
: "${KEYCHAIN_PASSWORD:?KEYCHAIN_PASSWORD secret is required}"
: "${GITHUB_ENV:?This script is intended for GitHub Actions}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

signing_dir="$(mktemp -d "${RUNNER_TEMP}/miband-signing.XXXXXX")"
certificate_path="${signing_dir}/certificate.p12"
profile_source_path="${signing_dir}/profile.mobileprovision"
profile_plist_path="${signing_dir}/profile.plist"
keychain_path="${RUNNER_TEMP}/miband-signing.keychain-db"

printf '%s' "${BUILD_CERTIFICATE_BASE64}" | base64 -D > "${certificate_path}"
printf '%s' "${PROVISIONING_PROFILE_BASE64}" | base64 -D > "${profile_source_path}"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${keychain_path}"
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${keychain_path}"
security import "${certificate_path}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${keychain_path}"
security set-key-partition-list -S apple-tool:,apple: -k "${KEYCHAIN_PASSWORD}" "${keychain_path}"
security list-keychains -d user -s "${keychain_path}"

code_sign_identity="$(security find-identity -v -p codesigning "${keychain_path}" | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1)"
if [[ -z "${code_sign_identity}" ]]; then
  echo "The imported certificate does not contain a usable code-signing identity." >&2
  exit 1
fi

security cms -D -i "${profile_source_path}" > "${profile_plist_path}"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "${profile_plist_path}")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "${profile_plist_path}")"
profile_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
profile_path="${profile_dir}/${profile_uuid}.mobileprovision"
mkdir -p "${profile_dir}"
cp "${profile_source_path}" "${profile_path}"

{
  echo "SIGNING_KEYCHAIN_PATH=${keychain_path}"
  echo "PROVISIONING_PROFILE_PATH=${profile_path}"
  echo "PROVISIONING_PROFILE_SPECIFIER=${profile_name}"
  echo "CODE_SIGN_IDENTITY_NAME=${code_sign_identity}"
} >> "${GITHUB_ENV}"
