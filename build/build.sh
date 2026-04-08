#!/bin/bash
# Build script for XDRMonitorControl
# Builds the app and copies the result to this build/ directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="XDRMonitorControl"
OUTPUT_DIR="$SCRIPT_DIR"
DERIVED_DATA_DIR="$SCRIPT_DIR/DerivedData"

echo "Building $APP_NAME..."

rm -rf "$DERIVED_DATA_DIR"

export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

BUILT_APP="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
APP_ENTITLEMENTS="$DERIVED_DATA_DIR/Build/Intermediates.noindex/MonitorControl.build/Release/MonitorControl.build/$APP_NAME.app.xcent"
USE_ADHOC_FALLBACK=0

sanitize_bundle_metadata() {
  local bundle_path="$1"

  if [ ! -d "$bundle_path" ]; then
    return
  fi

  xattr -cr "$bundle_path" 2>/dev/null || true
  xattr -rd com.apple.FinderInfo "$bundle_path" 2>/dev/null || true
  xattr -rd 'com.apple.fileprovider.fpfs#P' "$bundle_path" 2>/dev/null || true
}

run_xcodebuild() {
  xcodebuild \
    -project "$PROJECT_DIR/MonitorControl.xcodeproj" \
    -scheme "MonitorControl" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    "$@" \
    build
}

has_codesigning_identity() {
  security find-identity -v -p codesigning 2>/dev/null | grep -q '[1-9][0-9]* valid identities found'
}

set +e
if has_codesigning_identity; then
  run_xcodebuild
  BUILD_STATUS=$?
else
  BUILD_STATUS=1
fi
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
  USE_ADHOC_FALLBACK=1
  echo "No valid macOS code-signing identity was available. Falling back to ad-hoc signing."
  echo "Accessibility permission may need to be removed and re-added after each rebuild."
  rm -rf "$DERIVED_DATA_DIR"
  set +e
  run_xcodebuild CODE_SIGN_IDENTITY=-
  BUILD_STATUS=$?
  set -e
fi

if [ -d "$BUILT_APP" ]; then
  echo "Copying $APP_NAME.app to build/ ..."
  rm -rf "$OUTPUT_DIR/$APP_NAME.app"
  if [ "$USE_ADHOC_FALLBACK" -eq 1 ]; then
    ditto --norsrc "$BUILT_APP" "$OUTPUT_DIR/$APP_NAME.app"
  else
    ditto "$BUILT_APP" "$OUTPUT_DIR/$APP_NAME.app"
  fi
  sanitize_bundle_metadata "$OUTPUT_DIR/$APP_NAME.app"
  if [ "$USE_ADHOC_FALLBACK" -eq 1 ] && [ -f "$APP_ENTITLEMENTS" ]; then
    echo "Finalizing ad-hoc app signature..."
    /usr/bin/codesign --force --deep --sign - -o runtime --entitlements "$APP_ENTITLEMENTS" --timestamp=none --generate-entitlement-der "$OUTPUT_DIR/$APP_NAME.app"
    if [ "$BUILD_STATUS" -ne 0 ]; then
      echo "Recovered build output after Xcode codesign failure."
    fi
  fi
  echo "Done: $OUTPUT_DIR/$APP_NAME.app"
else
  echo "Error: built app not found at $BUILT_APP"
  exit "${BUILD_STATUS:-1}"
fi
