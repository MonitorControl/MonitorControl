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

	override func viewDidLoad() {
        super.viewDidLoad()

		listenFor.selectItem(at: prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
    }

	@IBAction func listenForChanged(_ sender: NSPopUpButton) {
		prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)

		#if DEBUG
		print("Toggle keys listened for state state -> \(sender.selectedItem?.title ?? "")")
		#endif

		NotificationCenter.default.post(name: Notification.Name.init(Utils.PrefKeys.listenFor.rawValue), object: nil)
	}

}
