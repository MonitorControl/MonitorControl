#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/monitorcontrol-settings-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/Sources/SettingsModel" "$test_root/Tests/SettingsModelTests"
cp "$project_root/MonitorControl/View Controllers/Preferences/SettingsPreferences.swift" "$test_root/Sources/SettingsModel/"
cp "$project_root/MonitorControl/Enums/PrefKey.swift" "$test_root/Sources/SettingsModel/"
cp "$project_root/Tests/SettingsPreferencesTests.swift" "$test_root/Tests/SettingsModelTests/"
cat > "$test_root/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "SettingsModel",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "SettingsModel"),
    .testTarget(name: "SettingsModelTests", dependencies: ["SettingsModel"]),
  ]
)
PACKAGE
swift test --package-path "$test_root"
