#!/bin/bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

xcodegen --version
xcodegen generate --spec project.yml
