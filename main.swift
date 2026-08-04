// Entry point. LSUIElement=YES in Info.plist keeps this out of the Dock.

import AppKit

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()
