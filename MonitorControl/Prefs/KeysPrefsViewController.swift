//
//  KeysPrefsViewController.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 07/01/2018.
//  MIT Licensed.
//

import Cocoa
import MASPreferences

class KeysPrefsViewController: NSViewController, MASPreferencesViewController {

	var viewIdentifier: String = "Keys"
	var toolbarItemLabel: String? = NSLocalizedString("Keys", comment: "Shown in the main prefs window")
	var toolbarItemImage: NSImage? = NSImage.init(named: NSImage.Name.init("KeyboardPref"))
	let prefs = UserDefaults.standard

	@IBOutlet var listenFor: NSPopUpButton!
	@IBOutlet var listenOn: NSPopUpButton!

	override func viewDidLoad() {
        super.viewDidLoad()

		listenFor.selectItem(at: prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
		listenOn.selectItem(at: prefs.integer(forKey: Utils.PrefKeys.listenOn.rawValue))
    }

	@IBAction func listenForChanged(_ sender: NSPopUpButton) {
		prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)
		// TODO: Toggle keys listened for state
		print("Toggle keys listened for state state -> \(sender.selectedItem?.title ?? "")")
	}

	@IBAction func listenOnChanged(_ sender: NSPopUpButton) {
		prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenOn.rawValue)
		// TODO: Toggle keys listened on state
		print("Toggle keys listened on state state -> \(sender.selectedItem?.title ?? "")")
	}
}
