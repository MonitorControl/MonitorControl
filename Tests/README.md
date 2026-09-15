# Night Shift controller tests

Run `./Tests/test-night-shift.sh` from the repository root on macOS 14 or later with Swift 5.9 or later. The script creates a temporary Swift package containing the actual controller source and its regression tests, then removes the temporary package when it finishes. It does not change system display settings.

The seven tests cover live readback, unavailable values, rejected writes, value clamping, stale reads, dragging and coalescing slow writes. These are controller tests; they do not verify private CoreBrightness APIs, physical displays or the appearance of the app menu.
