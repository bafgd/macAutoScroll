// Launch-at-login via SMAppService (macOS 13+). Older macOS just logs.

import Foundation
import ServiceManagement

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("AutoScroll: failed to update login item — \(error)")
            }
        } else {
            NSLog("AutoScroll: launch-at-login requires macOS 13 or later on this build")
        }
    }
}
