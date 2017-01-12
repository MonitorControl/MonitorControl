//
//  AppDelegate.swift
//  MonitorControl.OSX
//
//  Created by Mathew Kurian on 9/26/16.
//  Copyright © 2016 Mathew Kurian. All rights reserved.
//

import Cocoa
import Foundation

struct Display {
    var id: CGDirectDisplayID
    var name: String
    var serial: String
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var window: NSWindow!
    
    let prefs = UserDefaults.standard;
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    let keycode = UInt16(0x07)

    var displays : [Display] = []
    
    @IBAction func quitClicked(_ sender: AnyObject) {
        NSApplication.shared().terminate(self);
    }
    
    func setBrightness( slider: NSSlider ){
        let command = "-b";
        let value = slider.integerValue;
        let i = slider.tag;
        let d = displays[i]
        
        ddcctl(monitor: d.id, command: command, value: value);
        
        prefs.setValue(value, forKey: "\(command)-\(d.serial)");
        prefs.synchronize();
    }
    
    func setVolume(slider: NSSlider ){
        let command = "-v";
        let value = slider.integerValue;
        let i = slider.tag;
        let d = displays[i]

        ddcctl(monitor: d.id, command: command, value: value);

        prefs.setValue(value, forKey: "\(command)-\(d.serial)");
        prefs.synchronize();
    }

    func setContrast(slider: NSSlider ){
        let command = "-c";
        let value = slider.integerValue;
        let i = slider.tag;
        let d = displays[i]

        ddcctl(monitor: d.id, command: command, value: value);

        prefs.setValue(value, forKey: "\(command)-\(d.serial)");
        prefs.synchronize();
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.title = "♨"
        statusItem.menu = statusMenu

        var firstDisplay : Display? = nil

        for s in NSScreen.screens()! {
            let id = s.deviceDescription["NSScreenNumber"] as! CGDirectDisplayID
            if CGDisplayIsBuiltin(id) != 0 {
                continue
            }

            var edid = EDID()
            if !EDIDTest(id, &edid) {
                continue
            }

            let name = getDisplayName(edid)
            let serial = getDisplaySerial(edid)

            let d = Display(id: id, name: name, serial: serial)
            displays.append(d)

            let i = displays.count - 1

            let monitorMenuItem = NSMenuItem();
            let monitorSubMenu = NSMenu();

            let brightnessItem = NSMenuItem();
            let contrastItem = NSMenuItem();
            let volumeItem = NSMenuItem();
            let defaultMonitorItem = NSMenuItem();

            let brightnessSlider = NSSlider(frame: NSRect(x: 20, y: 0, width: 200, height: 19));

            brightnessSlider.target = self;
            brightnessSlider.minValue = 0;
            brightnessSlider.maxValue = 100;
            brightnessSlider.integerValue = prefs.integer(forKey: "-b-\(serial)")
            brightnessSlider.action = #selector(AppDelegate.setBrightness);
            brightnessSlider.tag = i;

            let contrastSlider = NSSlider(frame: NSRect(x: 20, y: 0, width: 200, height: 19));

            contrastSlider.target = self;
            contrastSlider.minValue = 0;
            contrastSlider.maxValue = 100;
            contrastSlider.integerValue = prefs.integer(forKey: "-c-\(serial)")
            contrastSlider.action = #selector(AppDelegate.setContrast);
            contrastSlider.tag = i;

            let volumeSlider = NSSlider(frame: NSRect(x: 20, y: 3, width: 200, height: 19));

            volumeSlider.target = self;
            volumeSlider.minValue = 0;
            volumeSlider.maxValue = 100;
            volumeSlider.integerValue = prefs.integer(forKey: "-v-\(serial)")
            volumeSlider.action = #selector(AppDelegate.setVolume);
            volumeSlider.tag = i;

            let brightnesSliderView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 40));
            let contrastSliderView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 40));
            let volumeSliderView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 40));
            let defaultMonitorView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 25));

            let brightnessLabel = NSTextField(frame: NSRect(x: 20, y: 16, width: 130, height: 20))
            brightnessLabel.stringValue = "Brightness";
            brightnessLabel.isBordered = false;
            brightnessLabel.isBezeled = false;
            brightnessLabel.isEditable = false
            brightnessLabel.drawsBackground = false

            let brightnessLabelKeyCode = NSTextField(frame: NSRect(x: 120, y: 16, width: 100, height: 20))
            brightnessLabelKeyCode.stringValue = "⇧⌘- / ⇧⌘+"
            brightnessLabelKeyCode.isBordered = false;
            brightnessLabelKeyCode.isBezeled = false;
            brightnessLabelKeyCode.isEditable = false
            brightnessLabelKeyCode.drawsBackground = false
            brightnessLabelKeyCode.isHidden = firstDisplay != nil;
            brightnessLabelKeyCode.alignment = NSTextAlignment.right

            let constrastLabel = NSTextField(frame: NSRect(x: 20, y: 16, width: 130, height: 20))
            constrastLabel.stringValue = "Contrast"
            constrastLabel.isBordered = false;
            constrastLabel.isBezeled = false;
            constrastLabel.isEditable = false
            constrastLabel.drawsBackground = false

            let volumeLabel = NSTextField(frame: NSRect(x: 20, y: 19, width: 130, height: 20))
            volumeLabel.stringValue = "Volume"
            volumeLabel.isBordered = false;
            volumeLabel.isBezeled = false;
            volumeLabel.isEditable = false
            volumeLabel.drawsBackground = false

            let volumeLabelKeyCode = NSTextField(frame: NSRect(x: 120, y: 19, width: 100, height: 20))
            volumeLabelKeyCode.stringValue = "⌥⌘- / ⌥⌘+"
            volumeLabelKeyCode.isBordered = false;
            volumeLabelKeyCode.isBezeled = false;
            volumeLabelKeyCode.isEditable = false;
            volumeLabelKeyCode.drawsBackground = false;
            volumeLabelKeyCode.isHidden = firstDisplay != nil;
            volumeLabelKeyCode.alignment = NSTextAlignment.right

            brightnesSliderView.addSubview(brightnessLabel)
            brightnesSliderView.addSubview(brightnessLabelKeyCode)
            brightnesSliderView.addSubview(brightnessSlider)

            contrastSliderView.addSubview(constrastLabel)
            contrastSliderView.addSubview(contrastSlider)

            volumeSliderView.addSubview(volumeLabel)
            volumeSliderView.addSubview(volumeLabelKeyCode)
            volumeSliderView.addSubview(volumeSlider)

            brightnessItem.view = brightnesSliderView;
            contrastItem.view = contrastSliderView;
            volumeItem.view = volumeSliderView;

            let defaultMonitorSelectButtom = NSButton(frame: NSRect(x: 25, y: 0, width: 200, height: 25));
            defaultMonitorSelectButtom.title = firstDisplay == nil ? "Default" : "Set as default";
            defaultMonitorSelectButtom.bezelStyle = NSRoundRectBezelStyle;
            defaultMonitorSelectButtom.isEnabled = firstDisplay != nil;
            defaultMonitorSelectButtom.tag = i;

            defaultMonitorView.addSubview(defaultMonitorSelectButtom);

            defaultMonitorItem.view = defaultMonitorView;

            monitorSubMenu.addItem(brightnessItem);
            monitorSubMenu.addItem(NSMenuItem.separator());
            monitorSubMenu.addItem(contrastItem);
            monitorSubMenu.addItem(NSMenuItem.separator());
            monitorSubMenu.addItem(volumeItem);
            monitorSubMenu.addItem(NSMenuItem.separator());
            monitorSubMenu.addItem(defaultMonitorItem);

            monitorMenuItem.title = "\(name)";
            monitorMenuItem.submenu = monitorSubMenu;

            statusMenu.insertItem(monitorMenuItem, at: i)

            if firstDisplay == nil {
                firstDisplay = d
            }
        }

        acquirePrivileges();

        if firstDisplay == nil {
            return
        }

        let d = firstDisplay!

        NSEvent.addGlobalMonitorForEvents(
            matching: NSEventMask.keyDown, handler: {(event: NSEvent) in
                if (event.keyCode == 27 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.control)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let value = abs(self.prefs.integer(forKey: "-v-\(d.serial)") - 1);

                    self.prefs.setValue(value, forKey: "-v-\(d.serial)");

                    self.ddcctl(monitor: d.id, command: "-v", value: value);
                    
                } else if (event.keyCode == 24 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.control)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let value = abs(self.prefs.integer(forKey: "-v-\(d.serial)") + 1);
                    
                    self.prefs.setValue(value, forKey: "-v-\(d.serial)");
                    
                    self.ddcctl(monitor: d.id, command: "-v", value: value);
                } else if (event.keyCode == 27 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.option)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let value = abs(self.prefs.integer(forKey: "-b-\(d.serial)") - 1);
                    
                    self.prefs.setValue(value, forKey: "-b-\(d.serial))");
                    
                    self.ddcctl(monitor: d.id, command: "-b", value: value);
                } else if (event.keyCode == 24 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.option)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let value = abs(self.prefs.integer(forKey: "-b-\(d.serial)") + 1);
                    
                    self.prefs.setValue(value, forKey: "-b-\(d.serial)");
                    
                    self.ddcctl(monitor: d.id, command: "-b", value: value);
                }
        });
    }
    
    func acquirePrivileges() {
        let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options);
        
        if !accessibilityEnabled {
            print("You need to enable the keylogger in the System Prefrences")
        }
        
        return;
    }
    
    func ddcctl(monitor: CGDirectDisplayID, command: String, value: Int) {
        var cmd : Int32! = nil
        switch command {
        case "-b":
            cmd = BRIGHTNESS
            break
        case "-v":
            cmd = AUDIO_SPEAKER_VOLUME
            break
        case "-c":
            cmd = CONTRAST
            break
        default:
            precondition(false, "Unknown command: \(command)")
        }

        var wrcmd = DDCWriteCommand(control_id: UInt8(cmd), new_value: UInt8(value))
        DDCWrite(monitor, &wrcmd)
        print(value)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func edidString(_ d: descriptor) -> String {
        var s = ""
        for (_, b) in Mirror(reflecting: d.text.data).children {
            let b = b as! Int8
            let c = Character(UnicodeScalar(UInt8(bitPattern: b)))
            if c == "\0" || c == "\n" {
                break
            }
            s.append(c)
        }
        return s
    }

    func getDescriptorString(_ edid: EDID, _ type: UInt8) -> String? {
        for d in [edid.descriptor1, edid.descriptor2, edid.descriptor3, edid.descriptor4] {
            if d.text.type == UInt8(type) {
                return edidString(d)
            }
        }

        return nil
    }

    func getDisplayName(_ edid: EDID) -> String {
        return getDescriptorString(edid, 0xFC) ?? "Display"
    }

    func getDisplaySerial(_ edid: EDID) -> String {
        return getDescriptorString(edid, 0xFF) ?? "Unknown"
    }
}
