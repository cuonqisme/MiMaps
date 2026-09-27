#!/bin/bash
set -euo pipefail

if [[ -n "${SIGNING_KEYCHAIN_PATH:-}" && -f "${SIGNING_KEYCHAIN_PATH}" ]]; then
  security delete-keychain "${SIGNING_KEYCHAIN_PATH}"
fi

if [[ -n "${PROVISIONING_PROFILE_PATH:-}" && -f "${PROVISIONING_PROFILE_PATH}" ]]; then
  rm -f "${PROVISIONING_PROFILE_PATH}"
fi
