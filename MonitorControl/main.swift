//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation

// Debug
let DEBUG_SW = false
let DEBUG_VIRTUAL = false
let DEBUG_MACOS10 = false
let DEBUG_GAMMA_ENFORCER = false
let DDC_MAX_DETECT_LIMIT: Int = 100

// Version
let MIN_PREVIOUS_BUILD_NUMBER = 6262

// App
var app: AppDelegate!
var menu: MenuHandler!

let prefs = UserDefaults.standard

// Views
private let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
let menuslidersPrefsVc = storyboard.instantiateController(withIdentifier: "MenuslidersPrefsVC") as? MenuslidersPrefsViewController
let keyboardPrefsVc = storyboard.instantiateController(withIdentifier: "KeyboardPrefsVC") as? KeyboardPrefsViewController
let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController
let onboardingVc = storyboard.instantiateController(withIdentifier: "onboardingViewController") as? NSWindowController

autoreleasepool { () in
  let mc = NSApplication.shared
  let mcDelegate = AppDelegate()
  mc.delegate = mcDelegate
  mc.run()
}
