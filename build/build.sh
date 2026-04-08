#!/bin/bash
# Build script for XDRMonitorControl
# Builds the app and copies the result to this build/ directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="XDRMonitorControl"
OUTPUT_DIR="$SCRIPT_DIR"

echo "Building $APP_NAME..."

xcodebuild \
  -project "$PROJECT_DIR/MonitorControl.xcodeproj" \
  -scheme "MonitorControl" \
  -configuration Release \
  -derivedDataPath "$SCRIPT_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT_APP="$SCRIPT_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ -d "$BUILT_APP" ]; then
  echo "Copying $APP_NAME.app to build/ ..."
  rm -rf "$OUTPUT_DIR/$APP_NAME.app"
  cp -r "$BUILT_APP" "$OUTPUT_DIR/$APP_NAME.app"
  echo "Done: $OUTPUT_DIR/$APP_NAME.app"
else
  echo "Error: built app not found at $BUILT_APP"
  exit 1
fi
