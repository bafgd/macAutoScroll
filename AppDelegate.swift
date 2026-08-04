// AppDelegate.swift
// Menu bar icon/menu, and opens the SwiftUI preferences window.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        EventTapManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Make sure we stop any in-progress scroll and restore the real
        // cursor before quitting cleanly.
        ScrollEngine.shared.stop()
        EventTapManager.shared.stopTap()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
                accessibilityDescription: "AutoScroll"
            )
        }

        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = SettingsStore.shared.settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AutoScroll", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        SettingsStore.shared.settings.isEnabled.toggle()
        sender.state = SettingsStore.shared.settings.isEnabled ? .on : .off
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            let hosting = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "AutoScroll Preferences"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 560))
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
