# Night Shift controller tests

Run `./Tests/test-night-shift.sh` from the repository root on macOS 14 or later with Swift 5.9 or later. The script creates a temporary Swift package containing the actual controller source and its regression tests, then removes the temporary package when it finishes. It does not change system display settings.

The seven tests cover live readback, unavailable values, rejected writes, value clamping, stale reads, dragging and coalescing slow writes. These are controller tests; they do not verify private CoreBrightness APIs, physical displays or the appearance of the app menu.

Run settings preference tests with `./Tests/test-settings.sh`. These cover stored and inverted values, callback ordering, external changes, reset reads and launch-at-login status.

Run native settings window checks with `./Tests/test-settings-window.sh`. These cover tiny saved window recovery, page changes without resizing, toolbar and sidebar safe areas, a single Displays scroller, resizing and sidebar collapse. Legacy content is represented by fixtures; these checks do not exercise physical displays.
