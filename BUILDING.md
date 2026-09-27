# Building

The project is generated from `project.yml`; the generated Xcode project is intentionally not committed.

## macOS

Requirements: Xcode 26.6, XcodeGen 2.44.1, and an iOS 16 or newer simulator.

```bash
bash scripts/ci/bootstrap.sh
bash scripts/ci/test.sh
```

Create an unsigned device archive that proves the Release configuration compiles:

```bash
ARCHIVE_PATH=artifacts/release/MiBandNavigator.xcarchive \
  bash scripts/build/archive.sh unsigned
```

An unsigned archive is not installable. A real IPA requires Apple signing assets as described in `APPLE_SIGNING.md`.

## Windows

Xcode cannot build iOS apps on Windows. Push the branch and use GitHub Actions. See `WINDOWS_DEVELOPMENT.md`.
