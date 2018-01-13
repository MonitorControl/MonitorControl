//
//  MainPrefsViewController.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 07/01/2018.
//  MIT Licensed.
//

import Cocoa
import MASPreferences
import ServiceManagement

class MainPrefsViewController: NSViewController, MASPreferencesViewController {

	var viewIdentifier: String = "Main"
	var toolbarItemLabel: String? = NSLocalizedString("General", comment: "Shown in the main prefs window")
	var toolbarItemImage: NSImage? = NSImage.init(named: .preferencesGeneral)
	let prefs = UserDefaults.standard

	@IBOutlet var startAtLogin: NSButton!
	@IBOutlet var startWhenExternal: NSButton!

	override func viewDidLoad() {
        super.viewDidLoad()

		startAtLogin.state = prefs.bool(forKey: Utils.PrefKeys.startAtLogin.rawValue) ? .on : .off
		startWhenExternal.state = prefs.bool(forKey: Utils.PrefKeys.startWhenExternal.rawValue) ? .on : .off
    }

	@IBAction func startAtLoginClicked(_ sender: NSButton) {
		let identifier = "me.guillaumeb.MonitorControlHelper" as CFString
		switch sender.state {
		case .on:
			prefs.set(true, forKey: Utils.PrefKeys.startAtLogin.rawValue)
			SMLoginItemSetEnabled(identifier, true)
		case .off:
			prefs.set(false, forKey: Utils.PrefKeys.startAtLogin.rawValue)
			SMLoginItemSetEnabled(identifier, false)
		default: break
		}
		print("Toggle start at login state -> \(sender.state == .on ? "on" : "off")")
	}

	@IBAction func startWhenExternalClicked(_ sender: NSButton) {
		switch sender.state {
		case .on:
			prefs.set(true, forKey: Utils.PrefKeys.startWhenExternal.rawValue)
		case .off:
			prefs.set(false, forKey: Utils.PrefKeys.startWhenExternal.rawValue)
		default: break
		}
		// TODO: Toggle start when external plugged in state
		print("Toggle start when external plugged in state -> \(sender.state == .on ? "on" : "off")")
	}
}
