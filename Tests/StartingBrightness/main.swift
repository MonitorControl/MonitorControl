// Run with swiftc MonitorControl/Support/StartingBrightness.swift Tests/StartingBrightness/main.swift -o /tmp/test-starting-brightness
for invalid: Float in [.nan, .infinity, -.infinity, -0.1, 0, 1.1] {
  precondition(StartingBrightness(builtInLevel: invalid) == nil)
}
let recommendation = StartingBrightness(builtInLevel: 0.69)!
precondition(recommendation.percent == 46)
precondition(recommendation.wouldDim(0.75))
precondition(!recommendation.wouldDim(0.44))
precondition(!recommendation.wouldDim(0.46))
precondition(!recommendation.wouldDim(0.461))
precondition(!recommendation.wouldDim(.nan))
precondition(!recommendation.wouldDim(1.1))
var previous = 0
for step in 1 ... 1000 {
  let suggestion = StartingBrightness(builtInLevel: Float(step) / 1000)!
  precondition((15 ... 67).contains(suggestion.percent) && previous <= suggestion.percent)
  previous = suggestion.percent
  for slider in 0 ... 100 {
    let current = Float(slider) / 100
    if suggestion.wouldDim(current) {
      precondition(suggestion.level < current)
    }
  }
}
precondition(StartingBrightness.permitsHardwareTarget(0, inverted: false, reading: nil))
precondition(!StartingBrightness.permitsHardwareTarget(1, inverted: false, reading: nil))
precondition(!StartingBrightness.permitsHardwareTarget(0, inverted: true, reading: nil))
precondition(!StartingBrightness.permitsHardwareTarget(3, inverted: false, reading: (1, 100)))
precondition(StartingBrightness.permitsHardwareTarget(3, inverted: false, reading: (5, 100)))
precondition(StartingBrightness.permitsHardwareTarget(6, inverted: true, reading: (5, 100)))
precondition(!StartingBrightness.permitsHardwareTarget(4, inverted: true, reading: (5, 100)))
precondition(!StartingBrightness.permitsHardwareTarget(105, inverted: true, reading: (5, 100)))
precondition(!StartingBrightness.permitsHardwareTarget(1, inverted: false, reading: (110, 100)))
precondition(!StartingBrightness.permitsHardwareTarget(1, inverted: false, reading: (0, 0)))
precondition(!StartingBrightness.permitsSoftwareTarget(0.82, reading: nil))
precondition(!StartingBrightness.permitsSoftwareTarget(0.82, reading: .infinity))
precondition(!StartingBrightness.permitsSoftwareTarget(0.82, reading: .nan))
precondition(!StartingBrightness.permitsSoftwareTarget(0.82, reading: 0.81))
precondition(StartingBrightness.permitsSoftwareTarget(0.82, reading: 1))
print("Starting brightness checks passed.")
