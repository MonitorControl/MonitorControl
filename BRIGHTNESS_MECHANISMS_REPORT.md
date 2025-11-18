# Display.swift Brightness Control Mechanisms - Detailed Analysis

## Overview
The `/home/user/brightness_checker/MonitorControl/Model/Display.swift` file implements a sophisticated multi-layered brightness control system that supports both hardware DDC/CI brightness and software-based brightness through gamma table manipulation or overlay shades.

---

## 1. Brightness Control Method Hierarchy

### 1.1 Primary Entry Point: `setBrightness()`
**Location:** Lines 111-117

```swift
func setBrightness(_ to: Float = -1, slow: Bool = false) -> Bool {
    if !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) {
        return self.setSmoothBrightness(to, slow: slow)
    } else {
        return self.setDirectBrightness(to)
    }
}
```

**Purpose:** Main brightness setter that routes to either smooth or direct brightness based on user preferences.

**Flow:**
- Checks global preference `disableSmoothBrightness`
- If smooth transitions enabled → calls `setSmoothBrightness()`
- If smooth transitions disabled → calls `setDirectBrightness()`

---

### 1.2 Smooth Brightness: `setSmoothBrightness()`
**Location:** Lines 119-170

**Purpose:** Implements animated brightness transitions with gradual stepping to avoid jarring changes.

#### Algorithm:

1. **Safety Checks:**
   ```swift
   guard app.sleepID == 0, app.reconfigureID == 0 else {
       // Stop if system is sleeping or reconfiguring displays
       return false
   }
   ```

2. **Step Division Logic:**
   ```swift
   var stepDivider: Float = 6        // Normal speed
   if self.smoothBrightnessSlow {
       stepDivider = 16              // Slow mode (2.67x slower)
   }
   ```
   - Normal mode: divides remaining distance by 6
   - Slow mode: divides remaining distance by 16 (for more gradual transitions)

3. **Goal Setting (when `to != -1`):**
   ```swift
   let value = max(min(to, 1), 0)
   self.savePref(value, for: .brightness)
   self.brightnessSyncSourceValue = value
   ```
   - Clamps value to [0, 1]
   - Saves as target brightness preference
   - Prevents duplicate smooth transition if already running

4. **Transition Stepping:**
   ```swift
   if brightness > self.smoothBrightnessTransient {
       self.smoothBrightnessTransient += max((brightness - self.smoothBrightnessTransient) / stepDivider, 1/100)
   } else {
       self.smoothBrightnessTransient += min((brightness - self.smoothBrightnessTransient) / stepDivider, 1/100)
   }
   ```
   - Calculates next step as fraction of remaining distance
   - Minimum step size: 1/100 (0.01) to ensure progress
   - Maximum step size: (remaining_distance / stepDivider)

5. **Termination:**
   ```swift
   if abs(brightness - self.smoothBrightnessTransient) < 0.01 {
       self.smoothBrightnessTransient = brightness
       dontPushAgain = true
       self.smoothBrightnessRunning = false
   }
   ```
   - Stops when within 0.01 of target
   - Snaps to exact target value

6. **Recursive Scheduling:**
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
       _ = self.setSmoothBrightness()
   }
   ```
   - Schedules next step in 20ms (50 FPS)
   - Continues until target reached

7. **Applies each step via:**
   ```swift
   _ = self.setDirectBrightness(self.smoothBrightnessTransient, transient: true)
   ```

---

### 1.3 Direct Brightness: `setDirectBrightness()`
**Location:** Lines 172-183

**Purpose:** Immediately sets brightness without animation.

```swift
func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    let value = max(min(to, 1), 0)
    if self.setSwBrightness(value) {
        if !transient {
            self.savePref(value, for: .brightness)
            self.brightnessSyncSourceValue = value
            self.smoothBrightnessTransient = value
        }
        return true
    }
    return false
}
```

**Flow:**
1. Clamps value to [0, 1]
2. Calls `setSwBrightness()` to apply
3. If not transient (i.e., final value):
   - Saves to preferences
   - Updates sync source
   - Updates smooth brightness tracking variable

**Transient Mode:** Used by smooth brightness for intermediate steps that shouldn't be saved.

---

## 2. Software Brightness Implementation: `setSwBrightness()`

**Location:** Lines 213-260

**Purpose:** The core implementation that actually manipulates display brightness using either gamma tables or shades.

### 2.1 Thread Safety
```swift
self.swBrightnessSemaphore.wait()
// ... critical section ...
self.swBrightnessSemaphore.signal()
```
- Uses semaphore to prevent concurrent gamma table modifications
- Prevents race conditions and flickering

### 2.2 Brightness Transformation
```swift
currentValue = self.swBrightnessTransform(value: currentValue)
newValue = self.swBrightnessTransform(value: newValue)
```

Calls `swBrightnessTransform()` (lines 204-211) which applies a non-linear mapping:

```swift
func swBrightnessTransform(value: Float, reverse: Bool = false) -> Float {
    let lowTreshold: Float = prefs.bool(forKey: PrefKey.allowZeroSwBrightness.rawValue) ? 0.0 : 0.15
    if !reverse {
        return value * (1 - lowTreshold) + lowTreshold    // Maps [0,1] → [0.15,1]
    } else {
        return (value - lowTreshold) / (1 - lowTreshold)  // Maps [0.15,1] → [0,1]
    }
}
```

**Rationale:**
- Default minimum brightness: 15% (prevents totally black screen)
- Can be disabled with `allowZeroSwBrightness` preference
- Reverse transformation used when reading current brightness

### 2.3 Dual Implementation Paths

#### Path A: Virtual Displays or Gamma-Avoiding Mode
```swift
if self.isVirtual || self.readPrefAsBool(key: .avoidGamma) {
    return DisplayManager.shared.setShadeAlpha(value: 1 - newValue, displayID: ...)
}
```

**When Used:**
- Virtual displays (e.g., sidecar, airplay)
- User enabled "Avoid Gamma" preference (lines 78-84)
- Gamma interference detected from other apps (f.lux, Night Shift)

**Mechanism:**
- Creates a semi-transparent overlay window (shade)
- Sets alpha to `1 - brightness` (e.g., 70% brightness = 30% opacity shade)
- Shade dims the display visually without touching hardware

#### Path B: Gamma Table Manipulation (Default)
```swift
let gammaTableRed = self.defaultGammaTableRed.map { $0 * newValue }
let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * newValue }
let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * newValue }
CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount,
                            gammaTableRed, gammaTableGreen, gammaTableBlue)
```

**Mechanism:**
1. Takes default gamma tables (captured at init)
2. Multiplies all values by brightness scalar (0.0 to 1.0)
3. Applies modified tables via CoreGraphics API

**Example:**
- Default gamma value: 0.8
- Brightness: 50% (0.5)
- New gamma value: 0.8 * 0.5 = 0.4

This effectively reduces the output intensity of all color channels proportionally.

### 2.4 Smooth Gamma Transitions
```swift
if smooth {
    DispatchQueue.global(qos: .userInteractive).async {
        for transientValue in stride(from: currentValue, to: newValue, by: 0.005 * (currentValue > newValue ? -1 : 1)) {
            // Apply gamma table or shade at transientValue
            Thread.sleep(forTimeInterval: 0.001)  // 1ms delay between steps
        }
    }
}
```

**Optional smooth mode:**
- Steps in increments of 0.005 (0.5%)
- 1ms delay per step
- Runs in background thread (user interactive QoS)
- Can create very gradual fades when needed

---

## 3. Gamma Table Management

### 3.1 Default Gamma Table Capture: `swUpdateDefaultGammaTable()`
**Location:** Lines 193-202

```swift
func swUpdateDefaultGammaTable() {
    guard !self.isDummy else { return }

    CGGetDisplayTransferByTable(self.identifier, 256,
                                &self.defaultGammaTableRed,
                                &self.defaultGammaTableGreen,
                                &self.defaultGammaTableBlue,
                                &self.defaultGammaTableSampleCount)

    let redPeak = self.defaultGammaTableRed.max() ?? 0
    let greenPeak = self.defaultGammaTableGreen.max() ?? 0
    let bluePeak = self.defaultGammaTableBlue.max() ?? 0
    self.defaultGammaTablePeak = max(redPeak, greenPeak, bluePeak)
}
```

**Called:** During display initialization (line 76)

**Purpose:**
1. Captures the "factory default" gamma tables
2. Stores them in display instance variables
3. Calculates peak values for later comparison

**Gamma Table Structure:**
- 256 entries per color channel (R, G, B)
- Type: `CGGammaValue` (floating point)
- Represents input-to-output mapping curve
- Peak value typically ~1.0 for linear or calibrated displays

### 3.2 Reading Current Brightness: `getSwBrightness()`
**Location:** Lines 262-291

```swift
func getSwBrightness() -> Float {
    // For shades: read alpha
    if self.isVirtual || self.readPrefAsBool(key: .avoidGamma) {
        let rawBrightnessValue = 1 - (DisplayManager.shared.getShadeAlpha(displayID: ...) ?? 1)
        return self.swBrightnessTransform(value: rawBrightnessValue, reverse: true)
    }

    // For gamma: read current gamma tables
    var gammaTableRed = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableSampleCount: UInt32 = 0

    if CGGetDisplayTransferByTable(self.identifier, 256, &gammaTableRed,
                                   &gammaTableGreen, &gammaTableBlue,
                                   &gammaTableSampleCount) == CGError.success {
        let redPeak = gammaTableRed.max() ?? 0
        let greenPeak = gammaTableGreen.max() ?? 0
        let bluePeak = gammaTableBlue.max() ?? 0
        let gammaTablePeak = max(redPeak, greenPeak, bluePeak)

        let peakRatio = gammaTablePeak / self.defaultGammaTablePeak
        brightnessValue = round(self.swBrightnessTransform(value: peakRatio, reverse: true) * 256) / 256
    }

    return brightnessValue
}
```

**Brightness Calculation Algorithm:**
1. Get current gamma table from system
2. Find peak value across all channels
3. Calculate ratio: `current_peak / default_peak`
4. Apply reverse transformation to convert to user-facing brightness
5. Round to 1/256 precision

**Example:**
- Default peak: 1.0
- Current peak: 0.5
- Peak ratio: 0.5
- After reverse transform (assuming 15% min): `(0.5 - 0.15) / 0.85 = 0.41`
- Rounded: 0.41 (41% brightness)

---

## 4. Gamma Interference Detection

### 4.1 Detection Function: `checkGammaInterference()`
**Location:** Lines 293-323

**Purpose:** Detects when external apps (f.lux, Night Shift, etc.) modify gamma tables.

#### Conditions Required for Detection:
```swift
guard !self.isDummy,
      !DisplayManager.shared.gammaInterferenceWarningShown,
      !(prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue)),
      !self.readPrefAsBool(key: .avoidGamma),
      !self.isVirtual,
      !self.smoothBrightnessRunning,
      self.prefExists(key: .SwBrightness),
      abs(currentSwBrightness - self.readPrefAsFloat(key: .SwBrightness)) > 0.02
else { return }
```

**Checks:**
1. Not a dummy display
2. Warning hasn't been shown yet
3. Combined brightness is enabled
4. Gamma mode is active (not avoiding gamma)
5. Not a virtual display
6. Not currently animating brightness
7. Previous brightness value exists in prefs
8. **Mismatch detected:** Current gamma brightness differs from saved by >2%

#### Detection Response:
```swift
DisplayManager.shared.gammaInterferenceCounter += 1
_ = self.setSwBrightness(1)  // Reset to 100% to clear interference
```

**After 3 Detections:**
Shows alert dialog with two options:

1. **"I'll quit the other app"**
   - User handles manually
   - Stops watching for interference

2. **"Disable gamma control for my displays"**
   ```swift
   for otherDisplay in DisplayManager.shared.getOtherDisplays() {
       _ = otherDisplay.setSwBrightness(1)
       _ = otherDisplay.setDirectBrightness(1)
       otherDisplay.savePref(true, key: .avoidGamma)  // Enable shade mode
       _ = otherDisplay.setSwBrightness(1)
       DisplayManager.shared.gammaInterferenceWarningShown = false
       DisplayManager.shared.gammaInterferenceCounter = 0
   }
   ```
   - Resets all displays to 100% brightness
   - Enables `.avoidGamma` mode (switches to shades)
   - Destroys gamma tables interference
   - Resets counter for future detections

---

## 5. Shade vs Gamma Mode Decision

### 5.1 Mode Selection (in `init()`)
**Location:** Lines 78-84

```swift
if self.isVirtual || self.readPrefAsBool(key: PrefKey.avoidGamma), !self.isDummy {
    os_log("Creating or updating shade for display %{public}@", type: .info, String(self.identifier))
    _ = DisplayManager.shared.updateShade(displayID: self.identifier)
} else {
    os_log("Destroying shade (if exists) for display %{public}@", type: .info, String(self.identifier))
    _ = DisplayManager.shared.destroyShade(displayID: self.identifier)
}
```

### 5.2 When Shades Are Used:

1. **Virtual Displays (Always)**
   - Sidecar iPads
   - AirPlay displays
   - Virtual display adapters
   - Reason: May not support gamma table manipulation

2. **User Preference (Manual)**
   - `avoidGamma` preference enabled
   - User manually chose to avoid gamma
   - Perhaps due to color-critical work

3. **Gamma Interference (Automatic)**
   - Detected 3+ conflicts with other apps
   - User chose to disable gamma in alert
   - System switches all displays to shade mode

### 5.3 Shade Mechanism Details:

**Implementation:** (handled by DisplayManager, not in this file)
- Creates overlay window on display
- Sets window alpha: `alpha = 1 - brightness`
- Example: 60% brightness → 40% opacity black shade
- Positioned above all other windows
- Ignores mouse events (pass-through)

**Advantages:**
- No conflicts with color management apps
- Works on all display types
- Preserves original gamma curves

**Disadvantages:**
- Visible overlay (very slight performance impact)
- Cannot dim below ~10-15% effectively (too dark)
- May not work correctly with HDR content

### 5.4 Gamma Mode Details:

**Advantages:**
- No overlay artifacts
- Native brightness control
- Better low-brightness performance

**Disadvantages:**
- Conflicts with f.lux, Night Shift, color calibrators
- May interfere with professional color work
- Requires gamma table restoration on quit

---

## 6. Preference Storage

### 6.1 Key Types
```swift
private func getKey(key: PrefKey? = nil, for command: Command? = nil) -> String {
    (key ?? PrefKey.value).rawValue +
    (command != nil ? String((command ?? Command.none).rawValue) : "") +
    self.prefsId
}
```

**prefsId Format (line 74):**
```swift
self.prefsId = "(\(name.filter { !$0.isWhitespace })\(vendorNumber ?? 0)\(modelNumber ?? 0)@\(self.isVirtual ? (self.serialNumber ?? 9999) : identifier))"
```

**Example:** `"(DellU2720Q412345678@987654321)"`

### 6.2 Brightness-Related Preferences

| PrefKey | Command | Purpose | Type |
|---------|---------|---------|------|
| `.value` | `.brightness` | Target brightness | Float |
| `.SwBrightness` | - | Software brightness value | Float |
| `.avoidGamma` | - | Force shade mode | Bool |
| `.unavailableDDC` | `.brightness` | DDC unavailable flag | Bool |

### 6.3 Helper Functions

```swift
func savePref<T>(_ value: T, key: PrefKey? = nil, for command: Command? = nil)
func readPrefAsFloat(key: PrefKey? = nil, for command: Command? = nil) -> Float
func readPrefAsBool(key: PrefKey? = nil, for command: Command? = nil) -> Bool
func prefExists(key: PrefKey? = nil, for command: Command? = nil) -> Bool
```

---

## 7. Complete Brightness Flow Diagrams

### 7.1 User Adjusts Brightness

```
User Action (hotkey/slider)
    ↓
stepBrightness() or setValue()
    ↓
setBrightness(value, slow)
    ↓
    ├─[Smooth enabled]─→ setSmoothBrightness(value, slow)
    │                       ↓
    │                   Save target to prefs
    │                       ↓
    │                   Start 50Hz loop
    │                       ↓
    │                   Calculate next step (distance/divisor)
    │                       ↓
    │                   setDirectBrightness(step, transient: true)
    │                       ↓
    │                   setSwBrightness(step, noPrefSave: false)
    │                       ↓
    │                   [Check: Virtual or avoidGamma?]
    │                       ├─[YES]─→ setShadeAlpha(1 - brightness)
    │                       └─[NO]──→ CGSetDisplayTransferByTable(gamma * brightness)
    │                       ↓
    │                   Sleep 20ms
    │                       ↓
    │                   [Distance < 0.01?]
    │                       ├─[NO]──→ Loop again
    │                       └─[YES]─→ Complete, save final value
    │
    └─[Smooth disabled]─→ setDirectBrightness(value)
                            ↓
                        setSwBrightness(value)
                            ↓
                        [Check: Virtual or avoidGamma?]
                            ├─[YES]─→ setShadeAlpha(1 - brightness)
                            └─[NO]──→ CGSetDisplayTransferByTable(gamma * brightness)
                            ↓
                        Save to prefs
```

### 7.2 Reading Brightness

```
getBrightness()
    ↓
[Pref exists?]
    ├─[YES]─→ readPrefAsFloat(for: .brightness)
    └─[NO]──→ getSwBrightness()
                ↓
            [Virtual or avoidGamma?]
                ├─[YES]─→ getShadeAlpha() → return 1 - alpha
                └─[NO]──→ CGGetDisplayTransferByTable()
                            ↓
                        Find max(peak_red, peak_green, peak_blue)
                            ↓
                        ratio = current_peak / default_peak
                            ↓
                        brightness = swBrightnessTransform(ratio, reverse: true)
```

### 7.3 Gamma Interference Detection Flow

```
Periodic Check (via Timer)
    ↓
checkGammaInterference()
    ↓
getSwBrightness()  [Read current gamma]
    ↓
Compare to saved pref
    ↓
[Difference > 2%?]
    ├─[NO]──→ Return (no interference)
    └─[YES]─→ interferenceCounter++
                ↓
            setSwBrightness(1)  [Reset to 100%]
                ↓
            [Counter >= 3?]
                ├─[NO]──→ Wait for next check
                └─[YES]─→ Show Alert
                            ↓
                        User chooses:
                            ├─[Quit other app]─→ Stop watching
                            └─[Disable gamma]──→ For all displays:
                                                    - savePref(true, key: .avoidGamma)
                                                    - updateShade()
                                                    - Reset counter
```

---

## 8. Key Properties and State Variables

```swift
// Smooth brightness state
var smoothBrightnessTransient: Float = 1     // Current animated value (0-1)
var smoothBrightnessRunning: Bool = false    // Is animation in progress?
var smoothBrightnessSlow: Bool = false       // Use slow speed (16 vs 6 divisor)?

// Gamma table storage
var defaultGammaTableRed = [CGGammaValue](repeating: 0, count: 256)
var defaultGammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
var defaultGammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
var defaultGammaTableSampleCount: UInt32 = 0
var defaultGammaTablePeak: Float = 1         // Max value in default tables

// Thread safety
let swBrightnessSemaphore = DispatchSemaphore(value: 1)

// Brightness sync
var brightnessSyncSourceValue: Float = 1     // Last user-set value for sync
```

---

## 9. Edge Cases and Special Handling

### 9.1 Display Sleep/Wake
```swift
guard app.sleepID == 0, app.reconfigureID == 0 else {
    self.savePref(self.smoothBrightnessTransient, for: .brightness)
    self.smoothBrightnessRunning = false
    return false
}
```
- Stops smooth brightness during sleep
- Saves current transient value
- Prevents display issues during reconfiguration

### 9.2 Display Reconfiguration
- Calls `swUpdateDefaultGammaTable()` to re-capture gamma
- Gamma enforcer moves to active display
- Reapplies brightness after reconfiguration

### 9.3 Dummy Displays
```swift
guard !self.isDummy else {
    return true  // Pretend success
}
```
- Used for testing/debugging
- Skip all hardware operations
- Return success without doing anything

### 9.4 Brightness Clamping
All brightness values clamped to [0, 1]:
```swift
let value = max(min(to, 1), 0)
```

### 9.5 Minimum Brightness Protection
```swift
let lowTreshold: Float = prefs.bool(forKey: PrefKey.allowZeroSwBrightness.rawValue) ? 0.0 : 0.15
```
- Default: Cannot go below 15% (prevents black screen)
- Optional: Allow 0% with preference flag

---

## 10. CoreGraphics APIs Used

### 10.1 CGGetDisplayTransferByTable
```swift
CGGetDisplayTransferByTable(displayID, sampleCount,
                            &redTable, &greenTable, &blueTable, &actualCount)
```
**Purpose:** Reads current gamma lookup tables from display hardware

**Parameters:**
- `displayID`: CGDirectDisplayID
- `sampleCount`: Requested samples (256)
- `redTable`, `greenTable`, `blueTable`: Output arrays
- `actualCount`: Actual samples returned

**Returns:** CGError.success on success

### 10.2 CGSetDisplayTransferByTable
```swift
CGSetDisplayTransferByTable(displayID, sampleCount,
                            redTable, greenTable, blueTable)
```
**Purpose:** Writes new gamma lookup tables to display hardware

**Parameters:**
- `displayID`: CGDirectDisplayID
- `sampleCount`: Number of samples (256)
- `redTable`, `greenTable`, `blueTable`: Input arrays

**Effect:** Immediately changes display color/brightness response curve

---

## 11. Summary

The Display.swift brightness control system implements a sophisticated four-layer architecture:

1. **User Interface Layer:** `setBrightness()` - Routes to smooth or direct
2. **Animation Layer:** `setSmoothBrightness()` - 50Hz stepped transitions
3. **Direct Control Layer:** `setDirectBrightness()` - Immediate changes
4. **Hardware Layer:** `setSwBrightness()` - Gamma tables or shades

**Key Design Decisions:**

- **Dual Implementation:** Gamma tables (default) vs shades (fallback)
- **Non-linear Brightness:** 15% minimum to prevent unusable displays
- **Smooth Animations:** Adaptive step sizing with 20ms intervals
- **Interference Detection:** Automatic fallback when conflicts detected
- **Thread Safety:** Semaphore prevents gamma table corruption
- **Preference Persistence:** Per-display identification and storage

**The gamma table approach** multiplies default color curves by brightness scalar, effectively dimming output while maintaining color accuracy.

**The shade approach** overlays a semi-transparent window, providing brightness control when gamma manipulation is unavailable or undesirable.

Together, these mechanisms provide universal software brightness control across all display types, with graceful degradation when conflicts arise.
