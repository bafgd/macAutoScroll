// main.swift
// Entry point. LSUIElement=YES in Info.plist keeps this out of the Dock,
// so we don't need to set activation policy here.

import AppKit

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()
