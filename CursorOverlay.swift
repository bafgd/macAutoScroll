// macOS won't let a background app override the system cursor while
// another app is frontmost, so we fake it: hide the real cursor and
// float a small borderless window with our own icon at the pointer.
// Draws 9 states: neutral + 8 directional arrows.

import AppKit
import CoreGraphics

enum CursorDirection: CaseIterable {
    case neutral, n, s, e, w, ne, nw, se, sw
}

final class CursorOverlayController {
    static let shared = CursorOverlayController()

    private var window: NSWindow?
    private var imageView: NSImageView?
    private let icons: [CursorDirection: NSImage]
    private var isShowing = false
    private let size: CGFloat = 32

    private init() {
        icons = Self.generateIcons(size: 32)
    }

    // cgPoint is in CGEvent/Quartz coordinates (origin top-left, y-down)
    func show(at cgPoint: CGPoint) {
        guard SettingsStore.shared.settings.showCursorOverlay else { return }
        guard !isShowing else {
            move(to: cgPoint)
            return
        }
        isShowing = true
        CGDisplayHideCursor(CGMainDisplayID())

        let cocoaPoint = Self.convertToCocoaScreenPoint(cgPoint)
        let win = NSWindow(
            contentRect: NSRect(x: cocoaPoint.x - size / 2, y: cocoaPoint.y - size / 2, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = .popUpMenu
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let iv = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        iv.image = icons[.neutral]
        win.contentView?.addSubview(iv)
        win.orderFrontRegardless()

        window = win
        imageView = iv
    }

    func move(to cgPoint: CGPoint) {
        guard let win = window else { return }
        let cocoaPoint = Self.convertToCocoaScreenPoint(cgPoint)
        win.setFrameOrigin(NSPoint(x: cocoaPoint.x - size / 2, y: cocoaPoint.y - size / 2))
    }

    func updateDirection(_ direction: CursorDirection) {
        imageView?.image = icons[direction]
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        window?.orderOut(nil)
        window = nil
        imageView = nil
        CGDisplayShowCursor(CGMainDisplayID())
    }

    // Converts a Quartz point (top-left origin, y-down) to an AppKit
    // screen point (bottom-left origin, y-up). Assumes the primary
    // display defines the Quartz origin.
    private static func convertToCocoaScreenPoint(_ point: CGPoint) -> NSPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
        return NSPoint(x: point.x, y: primaryHeight - point.y)
    }

    // MARK: - Icon generation

    private static func generateIcons(size: CGFloat) -> [CursorDirection: NSImage] {
        var result: [CursorDirection: NSImage] = [:]
        for direction in CursorDirection.allCases {
            result[direction] = drawIcon(for: direction, size: size)
        }
        return result
    }

    private static func drawIcon(for direction: CursorDirection, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: size - 2, height: size - 2)).fill()

        let center = NSPoint(x: size / 2, y: size / 2)
        let arrows: [CursorDirection] = (direction == .neutral) ? [.n, .s, .e, .w] : [direction]
        for arrow in arrows {
            drawArrow(from: center, direction: arrow)
        }

        image.unlockFocus()
        return image
    }

    private static func drawArrow(from center: NSPoint, direction: CursorDirection) {
        let length: CGFloat = 10
        let angle = angleForDirection(direction)
        let tip = NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)

        NSColor.white.setStroke()
        let shaft = NSBezierPath()
        shaft.move(to: center)
        shaft.line(to: tip)
        shaft.lineWidth = 2
        shaft.stroke()

        let headAngle1 = angle + .pi * 0.8
        let headAngle2 = angle - .pi * 0.8
        let head1 = NSPoint(x: tip.x + cos(headAngle1) * 4, y: tip.y + sin(headAngle1) * 4)
        let head2 = NSPoint(x: tip.x + cos(headAngle2) * 4, y: tip.y + sin(headAngle2) * 4)

        let head = NSBezierPath()
        head.move(to: tip); head.line(to: head1)
        head.move(to: tip); head.line(to: head2)
        head.lineWidth = 2
        head.stroke()
    }

    private static func angleForDirection(_ direction: CursorDirection) -> CGFloat {
        switch direction {
        case .e: return 0
        case .ne: return .pi * 0.25
        case .n: return .pi * 0.5
        case .nw: return .pi * 0.75
        case .w: return .pi
        case .sw: return .pi * 1.25
        case .s: return .pi * 1.5
        case .se: return .pi * 1.75
        case .neutral: return 0
        }
    }
}
