#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/monitorcontrol-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/Sources/MenuControls" "$test_root/Tests/MenuControlsTests"
cp "$project_root/MonitorControl/Support/NightShiftTemperatureController.swift" "$test_root/Sources/MenuControls/"
cp "$project_root/Tests/NightShiftTemperatureControllerTests.swift" "$test_root/Tests/MenuControlsTests/"
cat > "$test_root/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "MenuControls",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "MenuControls"),
    .testTarget(name: "MenuControlsTests", dependencies: ["MenuControls"]),
  ]
)
PACKAGE
swift test --package-path "$test_root"
