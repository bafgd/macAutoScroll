// ScrollEngine.swift
// Runs a 60Hz tick while autoscroll is active: computes distance/direction
// from the origin point, applies dead zone + speed curve + axis lock, posts
// a synthetic scroll-wheel CGEvent, and updates the cursor overlay icon.

import CoreGraphics
import Foundation

final class ScrollEngine {
    static let shared = ScrollEngine()

    private var timer: Timer?
    private var origin: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var settings: AppSettings { SettingsStore.shared.settings }

    private(set) var isActive = false

    func start(origin: CGPoint) {
        self.origin = origin
        currentPoint = origin
        isActive = true
        CursorOverlayController.shared.show(at: origin)

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common so it keeps firing during menu tracking / window dragging.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func updatePointer(_ point: CGPoint) {
        currentPoint = point
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate()
        timer = nil
        CursorOverlayController.shared.hide()
    }

    private func tick() {
        guard isActive else { return }

        var dx = currentPoint.x - origin.x
        var dy = currentPoint.y - origin.y // CG coords: y grows downward

        switch settings.axisLock {
        case .verticalOnly: dx = 0
        case .horizontalOnly: dy = 0
        case .both: break
        }

        let distance = sqrt(dx * dx + dy * dy)
        guard distance > settings.deadZoneRadius else {
            CursorOverlayController.shared.move(to: currentPoint)
            CursorOverlayController.shared.updateDirection(.neutral)
            return
        }

        let effectiveDistance = distance - settings.deadZoneRadius
        // Distance past the dead zone that counts as "full deflection" for
        // the curve — user-configurable now instead of a hardcoded 100pt.
        let rampDistance = max(settings.maxSpeedDistance, 1.0)
        let normalizedDistance = min(effectiveDistance / rampDistance, 1.0)
        let speedFactor = pow(normalizedDistance, settings.accelerationExponent) * settings.maxScrollSpeed

        let unitX = dx / distance
        let unitY = dy / distance

        var scrollDeltaX = unitX * speedFactor
        var scrollDeltaY = unitY * speedFactor

        if settings.invertHorizontal { scrollDeltaX *= -1 }
        if settings.invertVertical { scrollDeltaY *= -1 }

        // Both axes get a baseline sign flip to match how synthetic scroll
        // deltas map to on-screen motion; the Invert toggles apply on top
        // of that baseline, so "not inverted" is the correct/natural
        // direction and checking Invert actually reverses it.
        postScroll(deltaX: Int32(-scrollDeltaX), deltaY: Int32(-scrollDeltaY))

        CursorOverlayController.shared.move(to: currentPoint)
        CursorOverlayController.shared.updateDirection(directionForAngle(dx: dx, dy: dy))
    }

    private func postScroll(deltaX: Int32, deltaY: Int32) {
        guard deltaX != 0 || deltaY != 0 else { return }
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else { return }
        event.post(tap: .cgSessionEventTap)
    }

    private func directionForAngle(dx: CGFloat, dy: CGFloat) -> CursorDirection {
        // Screen/CG space has y growing downward, so "north" (up) is -dy.
        let angle = atan2(-dy, dx)
        let degrees = angle * 180 / .pi
        let normalized = degrees < 0 ? degrees + 360 : degrees

        switch normalized {
        case 337.5...360, 0..<22.5: return .e
        case 22.5..<67.5: return .ne
        case 67.5..<112.5: return .n
        case 112.5..<157.5: return .nw
        case 157.5..<202.5: return .w
        case 202.5..<247.5: return .sw
        case 247.5..<292.5: return .s
        case 292.5..<337.5: return .se
        default: return .neutral
        }
    }
}
