#!/bin/bash
set -euo pipefail

mode="${1:-upload}"

if [[ "${mode}" == "preflight" ]]; then
  xcrun --find altool
  xcrun altool --help >/dev/null
  echo "App Store upload tooling is available."
  exit 0
fi

if [[ "${mode}" != "upload" ]]; then
  echo "Usage: $0 [preflight|upload]" >&2
  exit 64
fi

: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required}"
: "${ASC_PRIVATE_KEY_BASE64:?ASC_PRIVATE_KEY_BASE64 is required}"

if [[ "${CONFIRM_TESTFLIGHT_UPLOAD:-}" != "UPLOAD" ]]; then
  echo "Set CONFIRM_TESTFLIGHT_UPLOAD=UPLOAD to authorize an external TestFlight upload." >&2
  exit 64
fi

export_path="${EXPORT_PATH:-artifacts/release/export}"
release_dir="${RELEASE_DIR:-artifacts/release}"
upload_log="${UPLOAD_LOG:-${release_dir}/testflight-upload.log}"
ipa_path="$(find "${export_path}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"

if [[ -z "${ipa_path}" ]]; then
  echo "No IPA found in ${export_path}" >&2
  exit 1
fi

private_key_dir="${HOME}/.appstoreconnect/private_keys"
private_key_path="${private_key_dir}/AuthKey_${ASC_KEY_ID}.p8"
mkdir -p "${private_key_dir}" "${release_dir}"

cleanup() {
  rm -f "${private_key_path}"
}
trap cleanup EXIT

printf '%s' "${ASC_PRIVATE_KEY_BASE64}" | base64 -D > "${private_key_path}"
chmod 600 "${private_key_path}"

echo "Validating IPA with App Store Connect..."
xcrun altool \
  --validate-app \
  --file "${ipa_path}" \
  --type ios \
  --apiKey "${ASC_KEY_ID}" \
  --apiIssuer "${ASC_ISSUER_ID}" \
  --output-format json 2>&1 | tee "${upload_log}"

echo "Uploading IPA to App Store Connect..."
xcrun altool \
  --upload-app \
  --file "${ipa_path}" \
  --type ios \
  --apiKey "${ASC_KEY_ID}" \
  --apiIssuer "${ASC_ISSUER_ID}" \
  --output-format json 2>&1 | tee -a "${upload_log}"

{
  echo "App Store Connect accepted the upload for processing."
  echo "Build number: ${BUILD_NUMBER:-unknown}"
  echo "Uploaded at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${release_dir}/testflight-upload.txt"
