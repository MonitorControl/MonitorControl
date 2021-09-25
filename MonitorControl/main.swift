//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation

let DEBUG_SW = true
let DEBUG_VIRTUAL = false
let DEBUG_MACOS10 = false
let MIN_PREVIOUS_BUILD_NUMBER = 5560

var app: MonitorControl!
var menu: MenuHandler!

let prefs = UserDefaults.standard
let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
let menuslidersPrefsVc = storyboard.instantiateController(withIdentifier: "MenuslidersPrefsVC") as? MenuslidersPrefsViewController
let keyboardPrefsVc = storyboard.instantiateController(withIdentifier: "KeyboardPrefsVC") as? KeyboardPrefsViewController
let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController

autoreleasepool { () -> Void in
  let mc = NSApplication.shared
  let mcDelegate = MonitorControl()
  mc.delegate = mcDelegate
  mc.run()
}
