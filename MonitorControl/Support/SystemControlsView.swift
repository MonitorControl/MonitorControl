// Adapted from Crisp. Copyright (c) 2026 Didrik Galteland.
// Distributed under the MIT license; see MonitorControl/UI/Crisp-LICENSE.txt.

import SwiftUI

/// System-wide controls, displayed once below the monitor sliders.
struct SystemControlsView: View {
  @ObservedObject private var effects = CoreBrightnessService.shared
  let showEffects: Bool
  let showTemperature: Bool

  var body: some View {
    VStack(spacing: 4) {
      if self.showEffects {
        ScreenEffectsView()
      }
      if self.showTemperature, let temperature = effects.nightShiftTemperature {
        NightShiftTemperatureView(temperature: temperature, isEnabled: self.effects.nightShiftEnabled)
      }
    }
    .frame(width: MenuLayout.width)
    .padding(.vertical, 4)
  }
}

struct NightShiftTemperatureView: View {
  @AppStorage(PrefKey.enableSliderPercent.rawValue, store: prefs) private var showPercentage = false
  @ObservedObject var temperature: NightShiftTemperatureController
  let isEnabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Night Shift Temperature").font(.callout)
      if self.showPercentage, let strength = self.temperature.strength {
        Text(strength, format: .percent.precision(.fractionLength(0)))
          .font(.system(size: 11))
          .monospacedDigit()
          .foregroundColor(.secondary)
      }
      Slider(value: Binding(
        get: { self.temperature.strength ?? 0 },
        set: { value in Task { await self.temperature.setStrength(value) } }
      ), in: 0 ... 1) { editing in
        self.temperature.setEditing(editing)
        if !editing { Task { await self.temperature.refresh() } }
      }
      .controlSize(.small)
      .accessibilityLabel(Text("Night Shift Temperature"))
      HStack {
        Text("Less Warm")
        Spacer()
        Text("More Warm")
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
    .disabled(!self.isEnabled || self.temperature.strength == nil)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}

/// Full-width actions follow the same spacing as the display and system controls.
struct MenuActionRow: View {
  let title: String
  let symbol: String?
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: self.action) {
      HStack(spacing: 10) {
        if let symbol = self.symbol {
          Image(systemName: symbol)
            .font(.system(size: 16))
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        Text(self.title)
          .font(.system(size: 13))
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundColor(.primary)
      .padding(.horizontal, MenuLayout.inset)
      .frame(width: MenuLayout.width, height: self.symbol == nil ? 30 : 38)
      .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(self.isHovered ? 0.08 : 0)))
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .onHover { self.isHovered = $0 }
    .accessibilityLabel(Text(self.title))
  }
}
