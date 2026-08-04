// Core of the app. A system-wide CGEventTap watches for the trigger
// button (default: middle mouse) and handles two modes:
//   - Hold + drag: scroll live, stop on release.
//   - Quick click: toggle continuous scrolling until clicked again.
// Also cancels an active gesture on Esc or a left/right click.

import AppKit
import CoreGraphics
import Carbon.HIToolbox
import ApplicationServices

final class EventTapManager {
    static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var mouseDownTime: CFAbsoluteTime = 0
    private var mouseDownLocation: CGPoint = .zero
    private var mode: ScrollMode = .idle
    private var trustPollTimer: Timer?

    private let clickMaxDuration: CFAbsoluteTime = 0.25
    private let clickMaxMovement: CGFloat = 5.0

    // Tag stamped on synthetic click events we generate ourselves, so
    // our own tap ignores them instead of re-triggering a scroll gesture.
    private let syntheticEventTag: Int64 = 0x4155_544F // "AUTO"

    private var settings: AppSettings { SettingsStore.shared.settings }

    private var isFrontmostAppExcluded: Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return settings.excludedBundleIDs.contains(bundleID)
    }

    func start() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityAccess()
            return
        }

        // stop polling once we're actually running
        trustPollTimer?.invalidate()
        trustPollTimer = nil

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("AutoScroll: failed to create event tap — check Accessibility permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopTap() {
        trustPollTimer?.invalidate()
        trustPollTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // let our own synthetic clicks pass through untouched
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        // re-enable the tap if the system disabled it under load
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard settings.isEnabled else { return Unmanaged.passUnretained(event) }

        if mode == .idle && isFrontmostAppExcluded {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard button == settings.triggerButtonNumber else { return Unmanaged.passUnretained(event) }

            if mode == .clickToggle {
                // second click while toggled on -> stop
                mode = .idle
                ScrollEngine.shared.stop()
                return nil
            }

            mouseDownTime = CFAbsoluteTimeGetCurrent()
            mouseDownLocation = event.location
            mode = .holdDrag // provisional, resolved on mouse-up
            ScrollEngine.shared.start(origin: event.location)
            return nil // consume so the target app doesn't see the middle click

        case .otherMouseDragged:
            guard mode == .holdDrag else { return Unmanaged.passUnretained(event) }
            ScrollEngine.shared.updatePointer(event.location)
            return nil

        case .mouseMoved:
            guard mode == .clickToggle else { return Unmanaged.passUnretained(event) }
            ScrollEngine.shared.updatePointer(event.location)
            return Unmanaged.passUnretained(event) // don't swallow normal cursor movement

        case .otherMouseUp:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard button == settings.triggerButtonNumber else { return Unmanaged.passUnretained(event) }
            guard mode == .holdDrag else { return nil }

            let elapsed = CFAbsoluteTimeGetCurrent() - mouseDownTime
            let moved = hypot(event.location.x - mouseDownLocation.x, event.location.y - mouseDownLocation.y)

            if elapsed <= clickMaxDuration && moved <= clickMaxMovement {
                switch settings.quickClickAction {
                case .toggleScroll:
                    // resolves as a click -> switch to toggle mode
                    mode = .clickToggle
                case .passThroughClick:
                    // resolves as a click, replay it since we swallowed the original
                    mode = .idle
                    ScrollEngine.shared.stop()
                    replayClick(at: event.location, button: settings.triggerButtonNumber)
                }
            } else {
                // was a drag -> stop on release
                mode = .idle
                ScrollEngine.shared.stop()
            }
            return nil

        case .leftMouseDown, .rightMouseDown:
            guard mode != .idle else { return Unmanaged.passUnretained(event) }
            mode = .idle
            ScrollEngine.shared.stop()
            return nil // consume the cancelling click

        case .keyDown:
            guard mode != .idle else { return Unmanaged.passUnretained(event) }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == kVK_Escape {
                mode = .idle
                ScrollEngine.shared.stop()
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func replayClick(at location: CGPoint, button: Int64) {
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: .center) else { return }
        down.setIntegerValueField(.mouseEventButtonNumber, value: button)
        down.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        down.post(tap: .cgSessionEventTap)

        guard let up = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: .center) else { return }
        up.setIntegerValueField(.mouseEventButtonNumber, value: button)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        up.post(tap: .cgSessionEventTap)
    }

    private func requestAccessibilityAccess() {
        // make sure we're frontmost or the permission sheet may not show
        NSApp.activate(ignoringOtherApps: true)

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // poll until the user flips the switch in System Settings
        trustPollTimer?.invalidate()
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, AXIsProcessTrusted() else { return }
            self.trustPollTimer?.invalidate()
            self.trustPollTimer = nil
            self.start()
        }

        // the system prompt only shows once per binary, so give a manual
        // fallback in case it was already dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !AXIsProcessTrusted() else { return }
            self.showAccessibilityInstructions()
        }
    }

    private func showAccessibilityInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Needed"
        alert.informativeText = "AutoScroll needs Accessibility access to watch for the trigger button and scroll. If macOS didn't show a permission prompt (it only ever shows it once), open System Settings and enable AutoScroll under Privacy & Security > Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
