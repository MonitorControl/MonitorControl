//
//  DisplayPrefsViewController.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 07/01/2018.
//  MIT Licensed.
//

import Cocoa
import MASPreferences

class DisplayPrefsViewController: NSViewController, MASPreferencesViewController, NSTableViewDataSource, NSTableViewDelegate {

	var viewIdentifier: String = "Display"
	var toolbarItemLabel: String? = NSLocalizedString("Display", comment: "Shown in the main prefs window")
	var toolbarItemImage: NSImage? = NSImage.init(named: .computer)
	let prefs = UserDefaults.standard

	var displays: [Display] = []
	enum DisplayCell: String {
		case checkbox
		case name
		case identifier
	}

	@IBOutlet var allScreens: NSButton!
	@IBOutlet var displayList: NSTableView!

	override func viewDidLoad() {
        super.viewDidLoad()

		allScreens.state = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? .on : .off

		loadDisplayList()
    }

	@IBAction func allScreensTouched(_ sender: NSButton) {
		switch sender.state {
		case .on:
			prefs.set(true, forKey: Utils.PrefKeys.allScreens.rawValue)
		case .off:
			prefs.set(false, forKey: Utils.PrefKeys.allScreens.rawValue)
		default: break
		}

		#if DEBUG
		print("Toggle allScreens state -> \(sender.state == .on ? "on" : "off")")
		#endif
	}

	// MARK: - Table datasource

	func loadDisplayList() {
		for screen in NSScreen.screens {
			if let id = screen.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as? CGDirectDisplayID {
				// Is Built In Screen (e.g. MBP/iMac Screen)
				if CGDisplayIsBuiltin(id) != 0 {
					let display = Display(id, name: "Mac built-in Display", serial: "", isEnabled: false)
					displays.append(display)
					continue
				}

				// Does screen support EDID ?
				var edid = EDID()
				if !EDIDTest(id, &edid) {
					continue
				}

				let name = Utils.getDisplayName(forEdid: edid)
				let serial = Utils.getDisplaySerial(forEdid: edid)
				let isEnabled = (prefs.object(forKey: "\(id)-state") as? Bool) ?? true

				let display = Display(id, name: name, serial: serial, isEnabled: isEnabled)
				displays.append(display)
			}
		}
		displayList.reloadData()
	}

	func numberOfRows(in tableView: NSTableView) -> Int {
		return displays.count
	}

	// MARK: - Table delegate

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var cellType = DisplayCell.checkbox
		var checked = false
		var text = ""
		let display = displays[row]

		if tableColumn == tableView.tableColumns[0] {
			// Checkbox
			checked = display.isEnabled
		} else if tableColumn == tableView.tableColumns[1] {
			// Name
			text = display.name
			cellType = DisplayCell.name
		} else if tableColumn == tableView.tableColumns[2] {
			// Identifier
			text = "\(display.identifier)"
			cellType = DisplayCell.identifier
		}
		if cellType == DisplayCell.checkbox {
			if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? ButtonCellView {
				cell.button.state = checked ? .on : .off
				cell.display = display
				if display.name == "Mac built-in Display" {
					cell.button.isEnabled = false
				}
				return cell
			}
		} else {
			if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? NSTableCellView {
				cell.textField?.stringValue = text
				return cell
			}
		}

		return nil
	}
}
