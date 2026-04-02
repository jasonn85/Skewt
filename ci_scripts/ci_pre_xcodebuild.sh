#!/bin/bash
set -euo pipefail

XCB="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
METAL_MOUNT_GLOB="/Users/local/Library/Developer/DVTDownloads/MetalToolchain/mounts/*/Metal.xctoolchain"
METAL_EXPORTED_BUNDLE_GLOB="/Users/local/Library/Developer/DVTDownloads/Assets/MetalToolchain/*.exportedBundle"

has_metal_mount() {
  ls ${METAL_MOUNT_GLOB}/usr/bin/metal >/dev/null 2>&1
}

has_exported_bundle() {
  ls ${METAL_EXPORTED_BUNDLE_GLOB} >/dev/null 2>&1
}

metal_toolchain_ready() {
  has_metal_mount || has_exported_bundle
}

echo "Ensuring MetalToolchain is installed (CI phase: ${CI_XCODEBUILD_ACTION:-unknown})"

# Fast check: if the metal toolchain mount exists and has metal, we're good.
if metal_toolchain_ready; then
  echo "MetalToolchain already available."
  exit 0
fi

# Otherwise, try downloading the component. Retry because downloads can flake.
for attempt in 1 2 3; do
  echo "Attempt $attempt: downloading MetalToolchain component..."
  download_output="$("$XCB" -downloadComponent MetalToolchain 2>&1)" && download_status=0 || download_status=$?
  echo "$download_output"

  if [ "$download_status" -eq 0 ]; then
    echo "Download succeeded."
    break
  fi

  if printf '%s' "$download_output" | grep -q "already imported at"; then
    echo "MetalToolchain is already imported; continuing."
    break
  fi

  sleep $((attempt * 10))
done

# Verify after download
if ! metal_toolchain_ready; then
  echo "ERROR: MetalToolchain still not available after download."
  exit 1
fi

# Optional sanity check: libLTO presence (your test runner error)
if has_metal_mount && ! ls ${METAL_MOUNT_GLOB}/usr/lib/libLTO.dylib >/dev/null 2>&1; then
  echo "WARNING: MetalToolchain missing libLTO.dylib (may break code coverage in tests)."
fi

echo "MetalToolchain ready."
