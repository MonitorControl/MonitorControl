//  Copyright © MonitorControl. @waydabber and others
//  Adapted from BetterDisplay’s KeyboardShortcuts.swift replacement.
//  Preserves the KeyboardShortcuts UserDefaults keys and JSON representation.

import AppKit
import Carbon

private func shortcutsEventHandler(eventHandlerCall _: EventHandlerCallRef?, event: EventRef?, userData _: UnsafeMutableRawPointer?) -> OSStatus {
  KeyboardShortcuts.handleEvent(event)
}

enum KeyboardShortcuts {
  struct Name: Hashable, RawRepresentable {
    let rawValue: String
    let defaultShortcut: Shortcut?
    var shortcut: Shortcut? {
      KeyboardShortcuts.getShortcut(for: self)
    }

    init(_ name: String, default defaultShortcut: Shortcut? = nil) {
      self.rawValue = name
      self.defaultShortcut = defaultShortcut
      if let defaultShortcut, !KeyboardShortcuts.userDefaultsContains(name: self) {
        KeyboardShortcuts.setShortcut(defaultShortcut, for: self)
      }
    }

    init?(rawValue: String) {
      self.init(rawValue)
    }
  }

  struct Key: Hashable, RawRepresentable {
    static let `return` = Self(kVK_Return)
    static let space = Self(kVK_Space)
    static let tab = Self(kVK_Tab)
    static let pageUp = Self(kVK_PageUp)
    static let pageDown = Self(kVK_PageDown)
    static let home = Self(kVK_Home)
    static let end = Self(kVK_End)
    static let upArrow = Self(kVK_UpArrow)
    static let rightArrow = Self(kVK_RightArrow)
    static let downArrow = Self(kVK_DownArrow)
    static let leftArrow = Self(kVK_LeftArrow)
    static let escape = Self(kVK_Escape)
    static let delete = Self(kVK_Delete)
    static let deleteForward = Self(kVK_ForwardDelete)
    static let help = Self(kVK_Help)
    static let f1 = Self(kVK_F1)
    static let f2 = Self(kVK_F2)
    static let f3 = Self(kVK_F3)
    static let f4 = Self(kVK_F4)
    static let f5 = Self(kVK_F5)
    static let f6 = Self(kVK_F6)
    static let f7 = Self(kVK_F7)
    static let f8 = Self(kVK_F8)
    static let f9 = Self(kVK_F9)
    static let f10 = Self(kVK_F10)
    static let f11 = Self(kVK_F11)
    static let f12 = Self(kVK_F12)
    static let f13 = Self(kVK_F13)
    static let f14 = Self(kVK_F14)
    static let f15 = Self(kVK_F15)
    static let f16 = Self(kVK_F16)
    static let f17 = Self(kVK_F17)
    static let f18 = Self(kVK_F18)
    static let f19 = Self(kVK_F19)
    static let f20 = Self(kVK_F20)

    let rawValue: Int

    init(rawValue: Int) {
      self.rawValue = rawValue
    }

    private init(_ value: Int) {
      self.init(rawValue: value)
    }
  }

  struct Shortcut: Hashable, Codable {
    let carbonKeyCode: Int
    let carbonModifiers: Int
    var key: Key? {
      Key(rawValue: self.carbonKeyCode)
    }

    var modifiers: NSEvent.ModifierFlags {
      NSEvent.ModifierFlags(carbon: self.carbonModifiers)
    }

    init(carbonKeyCode: Int, carbonModifiers: Int = 0) {
      self.carbonKeyCode = carbonKeyCode
      self.carbonModifiers = NSEvent.ModifierFlags(carbon: carbonModifiers).carbon
    }

    init(event: NSEvent) {
      self.init(carbonKeyCode: Int(event.keyCode), carbonModifiers: event.modifiers.carbon)
    }
  }

  private final class HotKey {
    let shortcut: Shortcut
    let id: Int
    let ref: EventHotKeyRef
    let onKeyDown: (Shortcut) -> Void
    let onKeyUp: (Shortcut) -> Void

    init(shortcut: Shortcut, id: Int, ref: EventHotKeyRef, onKeyDown: @escaping (Shortcut) -> Void, onKeyUp: @escaping (Shortcut) -> Void) {
      self.shortcut = shortcut
      self.id = id
      self.ref = ref
      self.onKeyDown = onKeyDown
      self.onKeyUp = onKeyUp
    }
  }

  private static let userDefaultsPrefix = "KeyboardShortcuts_"
  private static let hotKeySignature: UInt32 = 1_397_967_699 // "SSKS", for compatibility with existing registrations.
  private static var hotKeyId = 0
  private static var eventHandler: EventHandlerRef?
  private static var hotKeys = [Int: HotKey]()
  private static var registeredShortcuts = Set<Shortcut>()
  private static var keyDownHandlers = [Name: [() -> Void]]()
  private static var keyUpHandlers = [Name: [() -> Void]]()
  private static var disabledNames = Set<Name>()
  static var isPaused = false {
    didSet {
      guard self.isPaused != oldValue else { return }
      if self.isPaused {
        // Let the recorder receive combinations that are already registered as hotkeys.
        for shortcut in self.registeredShortcuts {
          self.unregister(shortcut)
        }
      } else {
        for shortcut in self.shortcutsForHandlers {
          self.register(shortcut)
        }
      }
    }
  }

  static func onKeyDown(for name: Name, action: @escaping () -> Void) {
    self.keyDownHandlers[name, default: []].append(action)
    self.registerShortcutIfNeeded(for: name)
  }

  static func onKeyUp(for name: Name, action: @escaping () -> Void) {
    self.keyUpHandlers[name, default: []].append(action)
    self.registerShortcutIfNeeded(for: name)
  }

  /// Track disabled names independently so shared bindings remain registered while in use.
  static func enable(_ name: Name) {
    self.disabledNames.remove(name)
    self.registerShortcutIfNeeded(for: name)
  }

  static func disable(_ name: Name) {
    self.disabledNames.insert(name)
    if let shortcut = getShortcut(for: name) {
      self.unregisterIfUnused(shortcut)
    }
  }

  static func removeAllHandlers() {
    for shortcut in self.shortcutsForHandlers {
      self.unregister(shortcut)
    }
    self.keyDownHandlers = [:]
    self.keyUpHandlers = [:]
  }

  static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
    guard let shortcut else {
      self.userDefaultsRemove(name: name)
      return
    }
    self.userDefaultsSet(name: name, shortcut: shortcut)
  }

  static func getShortcut(for name: Name) -> Shortcut? {
    guard
      let data = UserDefaults.standard.string(forKey: userDefaultsKey(for: name))?.data(using: .utf8),
      let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
    else {
      return nil
    }
    return shortcut
  }

  fileprivate static func handleEvent(_ event: EventRef?) -> OSStatus {
    guard let event else {
      return OSStatus(eventNotHandledErr)
    }

    var eventHotKeyId = EventHotKeyID()
    let error = GetEventParameter(
      event,
      UInt32(kEventParamDirectObject),
      UInt32(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &eventHotKeyId
    )

    guard error == noErr else {
      return error
    }
    guard eventHotKeyId.signature == self.hotKeySignature, let hotKey = hotKeys[Int(eventHotKeyId.id)] else {
      return OSStatus(eventNotHandledErr)
    }

    switch Int(GetEventKind(event)) {
    case kEventHotKeyPressed:
      hotKey.onKeyDown(hotKey.shortcut)
      return noErr
    case kEventHotKeyReleased:
      hotKey.onKeyUp(hotKey.shortcut)
      return noErr
    default:
      return OSStatus(eventNotHandledErr)
    }
  }

  private static var shortcutsForHandlers: Set<Shortcut> {
    Set([keyDownHandlers.keys, keyUpHandlers.keys].flatMap { $0 }.filter { !disabledNames.contains($0) }.compactMap(\.shortcut))
  }

  private static func userDefaultsKey(for name: Name) -> String {
    "\(self.userDefaultsPrefix)\(name.rawValue)"
  }

  private static func registerShortcutIfNeeded(for name: Name) {
    guard !self.disabledNames.contains(name), let shortcut = getShortcut(for: name) else {
      return
    }
    self.register(shortcut)
  }

  private static func register(_ shortcut: Shortcut) {
    guard !self.isPaused, !self.registeredShortcuts.contains(shortcut) else {
      return
    }
    self.hotKeyId += 1

    var eventHotKey: EventHotKeyRef?
    let error = RegisterEventHotKey(
      UInt32(shortcut.carbonKeyCode),
      UInt32(shortcut.carbonModifiers),
      EventHotKeyID(signature: self.hotKeySignature, id: UInt32(self.hotKeyId)),
      GetEventDispatcherTarget(),
      0,
      &eventHotKey
    )

    guard error == noErr, let eventHotKey else {
      return
    }

    self.hotKeys[self.hotKeyId] = HotKey(
      shortcut: shortcut,
      id: self.hotKeyId,
      ref: eventHotKey,
      onKeyDown: self.handleOnKeyDown,
      onKeyUp: self.handleOnKeyUp
    )
    self.registeredShortcuts.insert(shortcut)
    self.setUpEventHandlerIfNeeded()
  }

  private static func unregister(_ shortcut: Shortcut) {
    for hotKey in self.hotKeys.values where hotKey.shortcut == shortcut {
      UnregisterEventHotKey(hotKey.ref)
      hotKeys.removeValue(forKey: hotKey.id)
    }
    self.registeredShortcuts.remove(shortcut)
  }

  private static func setUpEventHandlerIfNeeded() {
    guard self.eventHandler == nil, let dispatcher = GetEventDispatcherTarget() else {
      return
    }
    var eventSpecs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    InstallEventHandler(dispatcher, shortcutsEventHandler, eventSpecs.count, &eventSpecs, nil, &self.eventHandler)
  }

  private static func handleOnKeyDown(_ shortcut: Shortcut) {
    guard !self.isPaused else {
      return
    }
    for (name, handlers) in self.keyDownHandlers where !self.disabledNames.contains(name) && self.getShortcut(for: name) == shortcut {
      handlers.forEach { $0() }
    }
  }

  private static func handleOnKeyUp(_ shortcut: Shortcut) {
    guard !self.isPaused else {
      return
    }
    for (name, handlers) in self.keyUpHandlers where !self.disabledNames.contains(name) && self.getShortcut(for: name) == shortcut {
      handlers.forEach { $0() }
    }
  }

  private static func userDefaultsSet(name: Name, shortcut: Shortcut) {
    guard let encoded = try? JSONEncoder().encode(shortcut), let string = String(data: encoded, encoding: .utf8) else {
      return
    }
    let oldShortcut = self.getShortcut(for: name)
    UserDefaults.standard.set(string, forKey: self.userDefaultsKey(for: name))
    if let oldShortcut, oldShortcut != shortcut {
      self.unregisterIfUnused(oldShortcut)
    }
    self.registerShortcutIfNeeded(for: name)
    self.userDefaultsDidChange(name: name)
  }

  private static func userDefaultsRemove(name: Name) {
    guard let shortcut = getShortcut(for: name) else {
      return
    }
    UserDefaults.standard.set(false, forKey: self.userDefaultsKey(for: name))
    self.unregisterIfUnused(shortcut)
    self.userDefaultsDidChange(name: name)
  }

  private static func userDefaultsContains(name: Name) -> Bool {
    UserDefaults.standard.object(forKey: self.userDefaultsKey(for: name)) != nil
  }

  private static func userDefaultsDidChange(name: Name) {
    NotificationCenter.default.post(name: .shortcutByNameDidChange, object: nil, userInfo: ["name": name])
  }

  private static func unregisterIfUnused(_ shortcut: Shortcut) {
    guard !self.shortcutsForHandlers.contains(shortcut) else {
      return
    }
    self.unregister(shortcut)
  }
}

extension KeyboardShortcuts {
  final class RecorderCocoa: NSSearchField {
    private weak static var activeRecorder: RecorderCocoa?
    private let minimumWidth = 130.0
    private var eventMonitor: LocalEventMonitor?
    private var isRecording = false
    private var idlePlaceholder: String?
    private var observer: NSObjectProtocol?
    private var recordingObservers = [NSObjectProtocol]()
    private var cancelButton: NSButtonCell?

    var shortcutName: KeyboardShortcuts.Name {
      didSet {
        guard self.shortcutName != oldValue else {
          return
        }
        self.endRecording()
        self.setStringValue()
      }
    }

    override var canBecomeKeyView: Bool {
      false
    }

    override func isAccessibilityElement() -> Bool {
      true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
      .button
    }

    override func accessibilityLabel() -> String? {
      self.idlePlaceholder ?? placeholderString
    }

    override func accessibilityValue() -> String? {
      KeyboardShortcuts.getShortcut(for: self.shortcutName)?.shortcutGlyph
    }

    override func accessibilityPerformPress() -> Bool {
      guard isEnabled, window?.makeFirstResponder(self) == true else { return false }
      self.startRecording()
      return true
    }

    override var intrinsicContentSize: CGSize {
      var size = super.intrinsicContentSize
      size.width = self.minimumWidth
      return size
    }

    private var showsCancelButton: Bool {
      get { (cell as? NSSearchFieldCell)?.cancelButtonCell != nil }
      set { (cell as? NSSearchFieldCell)?.cancelButtonCell = newValue ? self.cancelButton : nil }
    }

    init(for name: KeyboardShortcuts.Name) {
      self.shortcutName = name
      super.init(frame: .zero)
      isEditable = false
      isSelectable = false
      placeholderString = NSLocalizedString("Record", comment: "Shortcut recorder placeholder")
      alignment = .center
      baseWritingDirection = .leftToRight // Keep modifier glyphs before digit and arrow keys in RTL.
      (cell as? NSSearchFieldCell)?.searchButtonCell = nil
      wantsLayer = true
      translatesAutoresizingMaskIntoConstraints = false
      setContentHuggingPriority(.defaultHigh, for: .vertical)
      setContentHuggingPriority(.defaultHigh, for: .horizontal)
      widthAnchor.constraint(greaterThanOrEqualToConstant: self.minimumWidth).isActive = true
      self.cancelButton = (cell as? NSSearchFieldCell)?.cancelButtonCell
      self.setStringValue()
      self.observer = NotificationCenter.default.addObserver(forName: .shortcutByNameDidChange, object: nil, queue: nil) { [weak self] notification in
        guard
          let self,
          let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name,
          name == self.shortcutName
        else {
          return
        }
        self.setStringValue()
      }
    }

    required init?(coder _: NSCoder) {
      nil
    }

    deinit {
      if isRecording {
        KeyboardShortcuts.isPaused = false
      }
      if let observer {
        NotificationCenter.default.removeObserver(observer)
      }
      for observer in recordingObservers {
        NotificationCenter.default.removeObserver(observer)
      }
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      self.endRecording()
    }

    override func viewDidHide() {
      super.viewDidHide()
      self.endRecording()
    }

    /// Keep first-responder ownership on the recorder, not NSSearchField's shared text editor.
    override var acceptsFirstResponder: Bool {
      isEnabled
    }

    override func becomeFirstResponder() -> Bool {
      guard isEnabled, window != nil, !isHiddenOrHasHiddenAncestor else { return false }
      self.startRecording()
      return true
    }

    override func resignFirstResponder() -> Bool {
      self.stopRecording()
      return true
    }

    /// Newer AppKit search fields contain interactive subviews; keep their clicks here too.
    override func hitTest(_ point: NSPoint) -> NSView? {
      super.hitTest(point) == nil ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
      guard isEnabled else { return }
      let cancelBounds: NSRect
      if #available(macOS 11.0, *) {
        cancelBounds = cancelButtonBounds
      } else {
        cancelBounds = (cell as? NSSearchFieldCell)?.cancelButtonRect(forBounds: bounds) ?? .zero
      }
      if self.showsCancelButton, cancelBounds.contains(convert(event.locationInWindow, from: nil)) {
        self.clear()
        return
      }
      if window?.makeFirstResponder(self) == true {
        self.startRecording()
      }
    }

    private func endRecording() {
      self.stopRecording()
      if window?.firstResponder === self {
        window?.makeFirstResponder(nil)
      }
    }

    private func stopRecording() {
      guard self.isRecording else { return }
      self.eventMonitor = nil
      for observer in self.recordingObservers {
        NotificationCenter.default.removeObserver(observer)
      }
      self.recordingObservers.removeAll()
      self.isRecording = false
      placeholderString = self.idlePlaceholder
      self.setStringValue()
      if Self.activeRecorder === self {
        Self.activeRecorder = nil
        KeyboardShortcuts.isPaused = false
      }
      needsDisplay = true
    }

    private func startRecording() {
      guard let window, !self.isRecording else { return }
      Self.activeRecorder?.endRecording()
      Self.activeRecorder = self
      self.idlePlaceholder = placeholderString
      self.isRecording = true
      placeholderString = NSLocalizedString("Press Shortcut", comment: "Shortcut recorder prompt")
      stringValue = ""
      self.showsCancelButton = KeyboardShortcuts.getShortcut(for: self.shortcutName) != nil
      KeyboardShortcuts.isPaused = true
      self.eventMonitor = LocalEventMonitor(events: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
        guard let self else { return event }
        return self.handle(event)
      }.start()
      for (name, object) in [
        (NSWindow.didResignKeyNotification, window as AnyObject),
        (NSWindow.willCloseNotification, window as AnyObject),
        (NSApplication.didResignActiveNotification, NSApp as AnyObject),
      ] {
        self.recordingObservers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { [weak self] _ in
          self?.endRecording()
        })
      }
      needsDisplay = true
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
      guard Self.activeRecorder === self, self.isRecording else { return event }
      guard let window, window.firstResponder === self, !isHiddenOrHasHiddenAncestor else {
        self.endRecording()
        return event
      }
      if !event.isKeyEvent {
        if event.window !== window || !bounds.contains(convert(event.locationInWindow, from: nil)) {
          self.endRecording()
        }
        return event
      }
      guard event.window === window else {
        self.endRecording()
        return event
      }

      if event.modifiers.isEmpty, event.specialKey == .tab {
        self.endRecording()
        return event
      }

      if event.modifiers.isEmpty, event.keyCode == kVK_Escape {
        self.endRecording()
        return nil
      }

      if event.modifiers.isEmpty, event.specialKey == .delete || event.specialKey == .deleteForward || event.specialKey == .backspace {
        self.clear()
        return nil
      }

      guard !event.modifiers.subtracting(.shift).isEmpty || event.specialKey?.isSupportedFunctionKey == true else {
        NSSound.beep()
        return nil
      }

      let shortcut = KeyboardShortcuts.Shortcut(event: event)

      if let menuItem = shortcut.takenByMainMenu {
        self.endRecording()
        NSAlert.showModal(for: window, title: String(format: NSLocalizedString("This keyboard shortcut is already used by the menu item \"%@\".", comment: "Shortcut conflict; menu item title"), menuItem.title))
        if window.isKeyWindow {
          window.makeFirstResponder(self)
        }
        return nil
      }

      guard !shortcut.isTakenBySystem else {
        self.endRecording()
        NSAlert.showModal(for: window, title: NSLocalizedString("This keyboard shortcut is used by the system.", comment: "Shortcut conflict"), message: NSLocalizedString("Keyboard shortcuts can be changed in system keyboard settings.", comment: "Shortcut conflict guidance"))
        if window.isKeyWindow {
          window.makeFirstResponder(self)
        }
        return nil
      }

      stringValue = shortcut.shortcutGlyph
      self.showsCancelButton = true
      self.saveShortcut(shortcut)
      self.endRecording()
      return nil
    }

    private func setStringValue() {
      stringValue = KeyboardShortcuts.getShortcut(for: self.shortcutName)?.shortcutGlyph ?? ""
      self.showsCancelButton = !stringValue.isEmpty
    }

    private func saveShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
      KeyboardShortcuts.setShortcut(shortcut, for: self.shortcutName)
    }

    private func clear() {
      self.saveShortcut(nil)
      self.setStringValue()
      self.endRecording()
    }
  }
}

private final class LocalEventMonitor {
  private let events: NSEvent.EventTypeMask
  private let callback: (NSEvent) -> NSEvent?
  private var monitor: AnyObject?

  init(events: NSEvent.EventTypeMask, callback: @escaping (NSEvent) -> NSEvent?) {
    self.events = events
    self.callback = callback
  }

  deinit {
    stop()
  }

  @discardableResult
  func start() -> Self {
    self.monitor = NSEvent.addLocalMonitorForEvents(matching: self.events, handler: self.callback) as AnyObject
    return self
  }

  private func stop() {
    guard let monitor else {
      return
    }
    NSEvent.removeMonitor(monitor)
  }
}

private let keyToCharacterMapping: [KeyboardShortcuts.Key: String] = [
  .return: "↩",
  .delete: "⌫",
  .deleteForward: "⌦",
  .end: "↘",
  .escape: "⎋",
  .help: "?⃝",
  .home: "↖",
  .space: "⎵",
  .tab: "⇥",
  .pageUp: "⇞",
  .pageDown: "⇟",
  .upArrow: "↑",
  .rightArrow: "→",
  .downArrow: "↓",
  .leftArrow: "←",
  .f1: "F1",
  .f2: "F2",
  .f3: "F3",
  .f4: "F4",
  .f5: "F5",
  .f6: "F6",
  .f7: "F7",
  .f8: "F8",
  .f9: "F9",
  .f10: "F10",
  .f11: "F11",
  .f12: "F12",
  .f13: "F13",
  .f14: "F14",
  .f15: "F15",
  .f16: "F16",
  .f17: "F17",
  .f18: "F18",
  .f19: "F19",
  .f20: "F20",
]

private extension KeyboardShortcuts.Shortcut {
  static var system: [Self] {
    var shortcutsUnmanaged: Unmanaged<CFArray>?
    guard
      CopySymbolicHotKeys(&shortcutsUnmanaged) == noErr,
      let shortcuts = shortcutsUnmanaged?.takeRetainedValue() as? [[String: Any]]
    else {
      return []
    }

    return shortcuts.compactMap {
      guard
        ($0[kHISymbolicHotKeyEnabled] as? Bool) == true,
        let carbonKeyCode = $0[kHISymbolicHotKeyCode] as? Int,
        let carbonModifiers = $0[kHISymbolicHotKeyModifiers] as? Int
      else {
        return nil
      }
      return Self(carbonKeyCode: carbonKeyCode, carbonModifiers: carbonModifiers)
    }
  }

  var isTakenBySystem: Bool {
    self != Self(carbonKeyCode: kVK_F12) && Self.system.contains(self)
  }

  var takenByMainMenu: NSMenuItem? {
    guard let mainMenu = NSApp.mainMenu else {
      return nil
    }
    return self.menuItemWithMatchingShortcut(in: mainMenu)
  }

  func menuItemWithMatchingShortcut(in menu: NSMenu) -> NSMenuItem? {
    for item in menu.items {
      if self.keyToCharacter() == item.keyEquivalent, modifiers == item.keyEquivalentModifierMask {
        return item
      }
      if let submenu = item.submenu, let menuItem = menuItemWithMatchingShortcut(in: submenu) {
        return menuItem
      }
    }
    return nil
  }

  func keyToCharacter() -> String? {
    if let key, let character = keyToCharacterMapping[key] {
      return character
    }

    guard
      let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
      let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else {
      return nil
    }

    let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
    let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
    var deadKeyState: UInt32 = 0
    let maxLength = 4
    var length = 0
    var characters = [UniChar](repeating: 0, count: maxLength)

    let error = UCKeyTranslate(
      keyLayout,
      UInt16(carbonKeyCode),
      UInt16(kUCKeyActionDisplay),
      0,
      UInt32(LMGetKbdType()),
      OptionBits(kUCKeyTranslateNoDeadKeysBit),
      &deadKeyState,
      maxLength,
      &length,
      &characters
    )

    guard error == noErr else {
      return nil
    }
    return String(utf16CodeUnits: characters, count: length)
  }
}

extension KeyboardShortcuts.Shortcut {
  var shortcutGlyph: String {
    modifiers.shortcutGlyph + (self.keyToCharacter()?.uppercased() ?? "?")
  }
}

private extension NSEvent {
  var isKeyEvent: Bool {
    type == .keyDown || type == .keyUp
  }

  var modifiers: ModifierFlags {
    modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .subtracting([.capsLock, .numericPad, .function])
  }
}

private extension NSEvent.SpecialKey {
  var isSupportedFunctionKey: Bool {
    switch self {
    case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
      true
    default:
      false
    }
  }
}

extension NSEvent.ModifierFlags {
  var carbon: Int {
    var flags = 0
    if contains(.control) {
      flags |= controlKey
    }
    if contains(.option) {
      flags |= optionKey
    }
    if contains(.shift) {
      flags |= shiftKey
    }
    if contains(.command) {
      flags |= cmdKey
    }
    return flags
  }

  init(carbon: Int) {
    self.init()
    if carbon & controlKey == controlKey {
      insert(.control)
    }
    if carbon & optionKey == optionKey {
      insert(.option)
    }
    if carbon & shiftKey == shiftKey {
      insert(.shift)
    }
    if carbon & cmdKey == cmdKey {
      insert(.command)
    }
  }

  public var shortcutGlyph: String {
    var shortcutGlyph = ""
    if contains(.control) {
      shortcutGlyph += "⌃"
    }
    if contains(.option) {
      shortcutGlyph += "⌥"
    }
    if contains(.shift) {
      shortcutGlyph += "⇧"
    }
    if contains(.command) {
      shortcutGlyph += "⌘"
    }
    return shortcutGlyph
  }
}

private extension NSAlert {
  convenience init(title: String, message: String? = nil) {
    self.init()
    messageText = title
    alertStyle = .warning
    if let message {
      informativeText = message
    }
  }

  @discardableResult
  static func showModal(for window: NSWindow? = nil, title: String, message: String? = nil) -> NSApplication.ModalResponse {
    NSAlert(title: title, message: message).runModal(for: window)
  }

  @discardableResult
  func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
    guard let window else {
      return self.runModal()
    }
    beginSheetModal(for: window) { code in
      NSApp.stopModal(withCode: code)
    }
    return NSApp.runModal(for: window)
  }
}

private extension Notification.Name {
  static let shortcutByNameDidChange = Self("KeyboardShortcuts_shortcutByNameDidChange")
}
