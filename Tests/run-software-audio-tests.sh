#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
sources=()
for file in MonitorControl/SoftwareAudio/*.swift; do
  [[ "$file" == */MonitorSoftwareAudio.swift ]] || sources+=("$file")
done
xcrun swiftc -target "$(uname -m)-apple-macos15.0" "${sources[@]}" Tests/SoftwareAudioTests.swift -o "$output/tests"
"$output/tests"
