import AppKit
import SwiftUI

private final class FixedSettingsFixture: NSViewController {
  override func loadView() {
    self.view = NSView(frame: NSRect(x: 0, y: 0, width: 730, height: 800))
    let body = NSView()
    body.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(body)
    NSLayoutConstraint.activate([
      body.widthAnchor.constraint(equalToConstant: 730),
      body.heightAnchor.constraint(equalToConstant: 800),
      body.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      body.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      body.topAnchor.constraint(equalTo: self.view.topAnchor),
      body.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])
  }
}

private final class ScrollingSettingsFixture: NSViewController {
  override func loadView() {
    self.view = NSView(frame: NSRect(x: 0, y: 0, width: 730, height: 533))
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 730, height: 1500))
    self.view.addSubview(scroll)
    NSLayoutConstraint.activate([
      self.view.widthAnchor.constraint(equalToConstant: 730),
      self.view.heightAnchor.constraint(equalToConstant: 533),
      scroll.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: self.view.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -30),
    ])
  }
}

@main
struct SettingsWindowLayoutCheck {
  static func main() {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let suite = "MonitorControl.WindowTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let keyboard = FixedSettingsFixture()
    let displays = ScrollingSettingsFixture()
    let about = FixedSettingsFixture()
    let controller = SettingsSplitViewController(
      preferences: SettingsPreferences(defaults: defaults),
      legacyController: { page in
        switch page {
        case .keyboard: return keyboard
        case .displays: return displays
        case .about: return about
        default: return nil
        }
      }, resetSettings: {}, quitApplication: {}
    )
    let name = "MonitorControl.WindowTests.\(UUID().uuidString)"
    let oldWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 180, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
    oldWindow.saveFrame(usingName: name)
    let window = SettingsWindow(content: controller, autosaveName: name)
    defer {
      window.close()
      NSWindow.removeFrame(usingName: name)
      defaults.removePersistentDomain(forName: suite)
    }
    func settle() {
      RunLoop.main.run(until: Date().addingTimeInterval(0.15))
      window.contentView?.layoutSubtreeIfNeeded()
    }
    func checkViewport() {
      let page = controller.splitViewItems[1].viewController.children[0].view
      let rect = page.convert(page.bounds, to: nil)
      precondition(rect.maxY <= window.contentLayoutRect.maxY + 1, "Page overlaps toolbar")
      precondition(rect.minY >= window.contentLayoutRect.minY - 1, "Page extends below window")
      let sidebar = controller.splitViewItems[0].viewController.children[0].view
      let sidebarRect = sidebar.convert(sidebar.bounds, to: nil)
      precondition(sidebarRect.maxY <= window.contentLayoutRect.maxY + 1, "Sidebar overlaps toolbar")
    }
    settle()
    precondition(window.frame.width >= 940 && window.frame.height >= 560, "Tiny saved frame was restored")
    window.setContentSize(SettingsWindow.defaultContentSize)
    window.orderBack(nil)
    settle()
    for _ in 0 ..< 2 {
      for page in SettingsPage.allCases {
        let frame = window.frame
        controller.navigation.selection = page
        settle()
        precondition(window.frame == frame, "Switching to \(page) changed the window frame")
        checkViewport()
        if page == .displays {
          precondition(controller.splitViewItems[1].viewController.children[0] === displays, "Displays gained an outer scrolling container")
        }
      }
    }
    window.setContentSize(NSSize(width: 1100, height: 800))
    settle()
    checkViewport()
    controller.toggleSidebar(nil)
    settle()
    checkViewport()
    controller.toggleSidebar(nil)
    settle()
    checkViewport()
    print("PASS: tiny frame recovery, ten page transitions without resizing, toolbar/sidebar safe areas, single Displays scroller, resize and sidebar collapse/expand.")
  }
}
