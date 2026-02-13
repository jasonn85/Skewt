#!/bin/bash
set -euo pipefail

XCB="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"

echo "Ensuring MetalToolchain is installed (CI phase: ${CI_XCODEBUILD_ACTION:-unknown})"

# Fast check: if the metal toolchain mount exists and has metal, we're good.
if ls /Users/local/Library/Developer/DVTDownloads/MetalToolchain/mounts/*/Metal.xctoolchain/usr/bin/metal >/dev/null 2>&1; then
  echo "MetalToolchain mount already present."
  exit 0
fi

# Otherwise, try downloading the component. Retry because downloads can flake.
for attempt in 1 2 3; do
  echo "Attempt $attempt: downloading MetalToolchain component..."
  if "$XCB" -downloadComponent MetalToolchain; then
    echo "Download succeeded."
    break
  fi
  sleep $((attempt * 10))
done

# Verify after download
if ! ls /Users/local/Library/Developer/DVTDownloads/MetalToolchain/mounts/*/Metal.xctoolchain/usr/bin/metal >/dev/null 2>&1; then
  echo "ERROR: MetalToolchain still not available after download."
  exit 1
fi

# Optional sanity check: libLTO presence (your test runner error)
if ! ls /Users/local/Library/Developer/DVTDownloads/MetalToolchain/mounts/*/Metal.xctoolchain/usr/lib/libLTO.dylib >/dev/null 2>&1; then
  echo "WARNING: MetalToolchain missing libLTO.dylib (may break code coverage in tests)."
fi

echo "MetalToolchain ready."
