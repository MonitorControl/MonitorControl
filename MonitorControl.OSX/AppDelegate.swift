//
//  AppDelegate.swift
//  MonitorControl.OSX
//
//  Created by Mathew Kurian on 9/26/16.
//  Copyright © 2016 Mathew Kurian. All rights reserved.
//

import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var window: NSWindow!
    
    let prefs = UserDefaults.standard;
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    let keycode = UInt16(0x07)
    
    @IBAction func quitClicked(_ sender: AnyObject) {
        NSApplication.shared().terminate(self);
    }
    
    func setBrightness( slider: NSSlider ){
        let command = "-b";
        let value = slider.integerValue;
        let monitor = slider.tag;
        
        ddcctl(monitor: String(monitor), command: command, value: String(value));
        
        prefs.setValue(value, forKey: "\(command)-\(monitor)");
        prefs.synchronize();
    }
    
    func setVolume(slider: NSSlider ){
        let command = "-v";
        let value = slider.integerValue;
        let monitor = slider.tag;
        
        ddcctl(monitor: String(monitor), command: command, value: String(value));
        
        prefs.setValue(value, forKey: "\(command)-\(monitor)");
        prefs.synchronize();
    }
    
    func setContrast(slider: NSSlider ){
        let command = "-c";
        let value = slider.integerValue;
        let monitor = slider.tag;
        
        ddcctl(monitor: String(monitor), command: command, value: String(value));
        
        prefs.setValue(value, forKey: "\(command)-\(monitor)");
        prefs.synchronize();
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.title = "♨"
        statusItem.menu = statusMenu;
        
        for i in (1...4).reversed() {
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
            brightnessSlider.integerValue = prefs.integer(forKey: "-b-\(i)")
            brightnessSlider.action = #selector(AppDelegate.setBrightness);
            brightnessSlider.tag = i;
            
            let contrastSlider = NSSlider(frame: NSRect(x: 20, y: 0, width: 200, height: 19));
            
            contrastSlider.target = self;
            contrastSlider.minValue = 0;
            contrastSlider.maxValue = 100;
            contrastSlider.integerValue = prefs.integer(forKey: "-c-\(i)")
            contrastSlider.action = #selector(AppDelegate.setContrast);
            contrastSlider.tag = i;
            
            let volumeSlider = NSSlider(frame: NSRect(x: 20, y: 3, width: 200, height: 19));
            
            volumeSlider.target = self;
            volumeSlider.minValue = 0;
            volumeSlider.maxValue = 100;
            volumeSlider.integerValue = prefs.integer(forKey: "-v-\(i)")
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
            
            let brightnessLabelKeyCode = NSTextField(frame: NSRect(x: 120, y: 16, width: 100, height: 20))
            brightnessLabelKeyCode.stringValue = "⇧⌘- / ⇧⌘+"
            brightnessLabelKeyCode.isBordered = false;
            brightnessLabelKeyCode.isBezeled = false;
            brightnessLabelKeyCode.isHidden = i != 1;
            brightnessLabelKeyCode.alignment = NSTextAlignment.right
            
            let constrastLabel = NSTextField(frame: NSRect(x: 20, y: 16, width: 130, height: 20))
            constrastLabel.stringValue = "Contrast"
            constrastLabel.isBordered = false;
            constrastLabel.isBezeled = false;
            
            let volumeLabel = NSTextField(frame: NSRect(x: 20, y: 19, width: 130, height: 20))
            volumeLabel.stringValue = "Volume"
            volumeLabel.isBordered = false;
            volumeLabel.isBezeled = false;
            
            let volumeLabelKeyCode = NSTextField(frame: NSRect(x: 120, y: 19, width: 100, height: 20))
            volumeLabelKeyCode.stringValue = "⌥⌘- / ⌥⌘+"
            volumeLabelKeyCode.isBordered = false;
            volumeLabelKeyCode.isBezeled = false;
            volumeLabelKeyCode.isHidden = i != 1;
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
            defaultMonitorSelectButtom.title = i == 1 ? "Default" : "Set as default";
            defaultMonitorSelectButtom.bezelStyle = NSRoundRectBezelStyle;
            defaultMonitorSelectButtom.isEnabled = i != 1;
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

            monitorMenuItem.title = "Monitor \(i)";
            monitorMenuItem.submenu = monitorSubMenu;
            
            statusMenu.insertItem(monitorMenuItem, at: 0)
        }
        
        acquirePrivileges();
        
        NSEvent.addGlobalMonitorForEvents(
            matching: NSEventMask.keyDown, handler: {(event: NSEvent) in
                if (event.keyCode == 27 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.control)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let monitor = 1;
                    let value = abs(self.prefs.integer(forKey: "-v-\(monitor)") - 1);
                    
                    self.prefs.setValue(value, forKey: "-v-\(monitor)");
                    
                    self.ddcctl(monitor: String(monitor), command: "-v", value: String(value));
                    
                } else if (event.keyCode == 24 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.control)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let monitor = 1;
                    let value = abs(self.prefs.integer(forKey: "-v-\(monitor)") + 1);
                    
                    self.prefs.setValue(value, forKey: "-v-\(monitor)");
                    
                    self.ddcctl(monitor: String(monitor), command: "-v", value: String(value));
                } else if (event.keyCode == 27 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.option)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let monitor = 1;
                    let value = abs(self.prefs.integer(forKey: "-b-\(monitor)") - 1);
                    
                    self.prefs.setValue(value, forKey: "-b-\(monitor)");
                    
                    self.ddcctl(monitor: String(monitor), command: "-b", value: String(value));
                } else if (event.keyCode == 24 &&
                    (event.modifierFlags.contains(NSEventModifierFlags.option)) &&
                    (event.modifierFlags.contains(NSEventModifierFlags.command))) {
                    let monitor = 1;
                    let value = abs(self.prefs.integer(forKey: "-b-\(monitor)") + 1);
                    
                    self.prefs.setValue(value, forKey: "-b-\(monitor)");
                    
                    self.ddcctl(monitor: String(monitor), command: "-b", value: String(value));
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
    
    func ddcctl(monitor: String, command: String, value: String) {
        let task = Process()
        
        task.launchPath = "/usr/local/bin/ddcctl"
        task.arguments = ["-d", monitor, command, value]
        task.launch()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
}
