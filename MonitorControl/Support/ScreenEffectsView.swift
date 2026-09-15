// Adapted from Crisp. Copyright (c) 2026 Didrik Galteland.
// Distributed under the MIT license; see MonitorControl/UI/Crisp-LICENSE.txt.

import SwiftUI

/// Night Shift / True Tone quick toggles (system-level, via CoreBrightnessService).
/// Circular button + label below, modeled on the Dark Mode / Night Shift / True Tone row in the macOS 26 system displays panel.
struct ScreenEffectsView: View {
  @ObservedObject private var effects = CoreBrightnessService.shared

  var body: some View {
    HStack(spacing: 0) {
      if self.effects.darkModeAvailable {
        EffectCircleButton(
          glyph: .darkMode,
          label: "Dark Mode",
          isOn: self.effects.darkModeEnabled
        ) {
          self.effects.setDarkMode(!self.effects.darkModeEnabled)
        }
        .frame(maxWidth: .infinity)
      }
      if self.effects.nightShiftAvailable {
        EffectCircleButton(
          glyph: .nightShift,
          label: "Night Shift",
          isOn: self.effects.nightShiftEnabled,
          onFill: .orange,
          onIcon: .white
        ) {
          self.effects.setNightShift(!self.effects.nightShiftEnabled)
        }
        .frame(maxWidth: .infinity)
      }
      if self.effects.trueToneAvailable {
        EffectCircleButton(
          glyph: .trueTone,
          label: "True Tone",
          isOn: self.effects.trueToneEnabled,
          onFill: .blue,
          onIcon: .white
        ) {
          self.effects.setTrueTone(!self.effects.trueToneEnabled)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .onAppear { self.effects.refresh() }
  }
}

/// No press feedback at all: the only visible change on click is the state
/// itself (fill + On/Off text). Anything else gets frozen mid-flight by the
/// dark mode crossfade snapshot and reads as a stuck button. No transaction
/// tampering here: that would also strip the panel's layout spring and make
/// the row jump instead of riding section expansions.
private struct InstantPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

/// Same circular toggle style as the system panel: off = translucent dark
/// circle; on = the effect's own tint (white for Dark Mode, orange for Night
/// Shift, blue for True Tone), matching the native panel.
private struct EffectCircleButton: View {
  let glyph: EffectGlyph
  let label: String
  let isOn: Bool
  var onFill: Color = .white
  var onIcon: Color = .black
  let action: () -> Void

  /// Resolve the label key through NSLocalizedString; Text(String) does not
  /// auto-localize unlike Text(LocalizedStringKey).
  private var localizedLabel: String {
    NSLocalizedString(self.label, comment: "")
  }

  var body: some View {
    Button {
      // Instant state flip, like the native Control Center circles.
      self.action()
    } label: {
      VStack(spacing: 5) {
        ZStack {
          Circle()
            .fill(self.isOn ? self.onFill : Color.primary.opacity(0.12))
            .frame(width: 36, height: 36)
          EffectGlyphView(glyph: self.glyph, color: self.isOn ? self.onIcon : .primary.opacity(0.85))
        }
        VStack(spacing: 1) {
          Text(self.localizedLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.primary)
          Text(self.isOn ? "On" : "Off")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(InstantPressStyle())
    .accessibilityLabel(Text(self.localizedLabel))
    .accessibilityValue(Text(self.isOn ? "On" : "Off"))
    .accessibilityAddTraits(.isButton)
  }
}

// MARK: - Effect glyphs

//
// Dark Mode maps to the public SF Symbol `circle.lefthalf.fill`. The Night Shift and
// True Tone glyphs use private system symbols that aren't in the public SF Symbols set,
// so no `Image(systemName:)` matches them; those two are hand-drawn to evoke the same
// glyphs (a sun-with-moon, a sun-with-stripes) without reproducing Apple's artwork:
// original monochrome vector shapes, tinted by the caller like a symbol.

enum EffectGlyph { case darkMode, nightShift, trueTone }

private struct EffectGlyphView: View {
  let glyph: EffectGlyph
  let color: Color

  var body: some View {
    switch self.glyph {
    case .darkMode:
      // Public SF Symbol: the closest match to the native Dark Mode glyph, and
      // fully covered by the SF Symbols license (unlike the private originals).
      Image(systemName: "circle.lefthalf.fill")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(self.color)
    case .nightShift:
      ZStack { SunRaysGlyph(color: self.color); CrescentGlyph(color: self.color) }
        .frame(width: 18, height: 18)
    case .trueTone:
      ZStack { SunRaysGlyph(color: self.color); StripedDiscGlyph(color: self.color) }
        .frame(width: 18, height: 18)
    }
  }
}

/// Eight short rounded rays around the center, the shared base of the Night Shift
/// and True Tone glyphs.
private struct SunRaysGlyph: View {
  let color: Color
  var body: some View {
    ZStack {
      ForEach(0 ..< 8, id: \.self) { i in
        Capsule(style: .continuous)
          .fill(self.color)
          .frame(width: 1.6, height: 3)
          .offset(y: -6.9)
          .rotationEffect(.degrees(Double(i) * 45))
      }
    }
    .frame(width: 18, height: 18)
  }
}

/// Crescent moon (a disc with an offset disc erased), the Night Shift center.
private struct CrescentGlyph: View {
  let color: Color
  var body: some View {
    Circle()
      .fill(self.color)
      .frame(width: 7.5, height: 7.5)
      .overlay(
        Circle()
          .fill(self.color)
          .frame(width: 6.5, height: 6.5)
          .offset(x: 2.3, y: -0.7)
          .blendMode(.destinationOut)
      )
      .compositingGroup()
  }
}

/// Disc crossed by horizontal gaps (a striped circle), the True Tone center.
private struct StripedDiscGlyph: View {
  let color: Color
  var body: some View {
    Circle()
      .fill(self.color)
      .frame(width: 7.5, height: 7.5)
      .overlay(
        VStack(spacing: 0.9) {
          ForEach(0 ..< 3, id: \.self) { _ in
            Rectangle().fill(self.color).frame(width: 7.5, height: 0.8)
          }
        }
        .blendMode(.destinationOut)
      )
      .compositingGroup()
  }
}
