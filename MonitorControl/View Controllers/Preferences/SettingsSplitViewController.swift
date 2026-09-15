// Copyright © MonitorControl contributors

import Combine
import SwiftUI

final class SettingsNavigation: ObservableObject {
  @Published var selection: SettingsPage

  init(selection: SettingsPage = .general) {
    self.selection = selection
  }
}

private struct SettingsSidebar: View {
  @ObservedObject var navigation: SettingsNavigation

  var body: some View {
    List(SettingsPage.allCases, selection: Binding(
      get: { Optional(self.navigation.selection) },
      set: { if let page = $0 { self.navigation.selection = page } }
    )) { page in
      Label(page.title, systemImage: page.symbol)
        .padding(.vertical, 4)
        .tag(page)
    }
    .listStyle(.sidebar)
  }
}

/// AppKit owns the window chrome and split view. Hosted forms own only their content.
final class SettingsSplitViewController: NSSplitViewController, NSToolbarDelegate {
  let navigation: SettingsNavigation
  private let preferences: SettingsPreferences
  private let legacyController: (SettingsPage) -> NSViewController?
  private let resetSettings: () -> Void
  private let quitApplication: () -> Void
  private let detail = SettingsDetailController()
  private var selectionObserver: AnyCancellable?
  private let dividerIdentifier = NSToolbarItem.Identifier("SettingsSidebarDivider")
  private let titleIdentifier = NSToolbarItem.Identifier("SettingsPageTitle")
  private let titleLabel = NSTextField(labelWithString: "")

  init(
    preferences: SettingsPreferences,
    initialPage: SettingsPage = .general,
    legacyController: @escaping (SettingsPage) -> NSViewController?,
    resetSettings: @escaping () -> Void,
    quitApplication: @escaping () -> Void
  ) {
    self.preferences = preferences
    self.navigation = SettingsNavigation(selection: initialPage)
    self.legacyController = legacyController
    self.resetSettings = resetSettings
    self.quitApplication = quitApplication
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder _: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.splitView.isVertical = true
    self.splitView.dividerStyle = .thin
    let sidebar = NSHostingController(rootView: SettingsSidebar(navigation: self.navigation))
    sidebar.sizingOptions = []
    let sidebarContainer = SettingsDetailController()
    sidebarContainer.show(sidebar)
    let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarContainer)
    sidebarItem.minimumThickness = 180
    sidebarItem.maximumThickness = 220
    sidebarItem.holdingPriority = .defaultHigh
    sidebarItem.canCollapse = true
    sidebarItem.canCollapseFromWindowResize = false
    sidebarItem.allowsFullHeightLayout = true
    let detailItem = NSSplitViewItem(viewController: self.detail)
    detailItem.minimumThickness = 760
    self.addSplitViewItem(sidebarItem)
    self.addSplitViewItem(detailItem)
    self.selectionObserver = self.navigation.$selection.removeDuplicates().sink { [weak self] page in
      self?.showPage(page)
    }
  }

  private func showPage(_ page: SettingsPage) {
    self.titleLabel.stringValue = page.title
    switch page {
    case .general:
      self.detail.show(self.host(GeneralSettingsView(preferences: self.preferences, resetSettings: self.resetSettings)))
    case .appearance:
      self.detail.show(self.host(AppearanceSettingsView(preferences: self.preferences, quitApplication: self.quitApplication)))
    case .keyboard, .about:
      if let controller = self.legacyController(page) {
        self.detail.show(LegacySettingsContainer(content: controller))
      }
    case .displays:
      if let controller = self.legacyController(page) {
        // This pane already owns a scrolling table and a fixed footer.
        // Release only its old standalone-window size constraints.
        _ = controller.view
        for constraint in controller.view.constraints
          where constraint.firstItem === controller.view && constraint.secondItem == nil
          && (constraint.firstAttribute == .width || constraint.firstAttribute == .height)
        {
          constraint.isActive = false
        }
        self.detail.show(controller)
      }
    }
  }

  private func host<Content: View>(_ content: Content) -> NSViewController {
    let controller = NSHostingController(rootView: content)
    // The split view sets the viewport. A Form's fitting size must not resize the window.
    controller.sizingOptions = []
    return controller
  }

  func makeToolbar() -> NSToolbar {
    _ = self.view
    let toolbar = NSToolbar(identifier: "MonitorControlSettings")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    return toolbar
  }

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    [.toggleSidebar, self.dividerIdentifier, self.titleIdentifier, .flexibleSpace]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    self.toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(_: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
    if identifier == self.dividerIdentifier {
      return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: self.splitView, dividerIndex: 0)
    }
    if identifier == self.titleIdentifier {
      let item = NSToolbarItem(itemIdentifier: identifier)
      self.titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
      item.view = self.titleLabel
      return item
    }
    return nil
  }
}

private final class SettingsDetailController: NSViewController {
  private let viewport = NSView()

  override func loadView() {
    self.view = NSView()
    self.viewport.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(self.viewport)
    let safeArea = self.view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      self.viewport.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
      self.viewport.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
      self.viewport.topAnchor.constraint(equalTo: safeArea.topAnchor),
      self.viewport.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
    ])
  }

  override func preferredContentSizeDidChange(for _: NSViewController) {
    // Pages scroll within this viewport; their preferred size does not size the window.
  }

  func show(_ controller: NSViewController) {
    _ = self.view
    for child in self.children {
      if let legacy = child as? LegacySettingsContainer { legacy.detachContent() }
      child.view.removeFromSuperview()
      child.removeFromParent()
    }
    self.addChild(controller)
    let content = controller.view
    // Keep each page's fitting size inside this viewport. It must not propagate
    // through the split view and change the window or sidebar when switching pages.
    content.translatesAutoresizingMaskIntoConstraints = true
    content.autoresizingMask = [.width, .height]
    content.frame = self.viewport.bounds
    self.viewport.addSubview(content)
  }
}

/// Disable hosting-driven window sizing and validate restored frames before showing them.
final class SettingsWindow: NSWindow {
  static let minimumContentSize = NSSize(width: 940, height: 560)
  static let defaultContentSize = NSSize(width: 960, height: 680)

  init(content: SettingsSplitViewController, autosaveName: String = "ModernSettingsWindow") {
    super.init(
      contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    self.title = NSLocalizedString("Settings", comment: "Settings window title")
    self.titleVisibility = .hidden
    self.toolbarStyle = .unified
    self.contentViewController = content
    self.toolbar = content.makeToolbar()
    self.isReleasedWhenClosed = false
    self.contentMinSize = Self.minimumContentSize
    self.setContentSize(Self.defaultContentSize)
    content.splitView.setPosition(190, ofDividerAt: 0)
    self.center()
    self.setFrameUsingName(autosaveName)
    self.validateSize()
    self.setFrameAutosaveName(autosaveName)
  }

  func validateSize() {
    self.contentMinSize = Self.minimumContentSize
    let size = self.contentRect(forFrameRect: self.frame).size
    if size.width < Self.minimumContentSize.width || size.height < Self.minimumContentSize.height {
      self.setContentSize(NSSize(
        width: max(size.width, Self.minimumContentSize.width),
        height: max(size.height, Self.minimumContentSize.height)
      ))
    }
  }
}
