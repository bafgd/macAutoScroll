// Settings.swift
// Persisted, customizable settings — this is the "customizability" half
// of the two must-have features.

import Foundation
import Combine

enum AxisLock: String, Codable, CaseIterable, Identifiable {
    case both, verticalOnly, horizontalOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .both: return "Both Axes"
        case .verticalOnly: return "Vertical Only"
        case .horizontalOnly: return "Horizontal Only"
        }
    }
}

/// Internal state machine for the event tap — not persisted.
enum ScrollMode {
    case idle
    case holdDrag
    case clickToggle
}

enum QuickClickAction: String, Codable, CaseIterable, Identifiable {
    /// Current behavior: a quick tap of the trigger button starts
    /// continuous scrolling that follows the cursor until clicked again.
    case toggleScroll
    /// A quick tap is replayed to the app underneath as a normal click —
    /// e.g. so middle-click still opens links in a browser. Only an
    /// actual hold + drag will scroll.
    case passThroughClick

    var id: String { rawValue }
    var label: String {
        switch self {
        case .toggleScroll: return "Toggle continuous scroll"
        case .passThroughClick: return "Act as a normal click (e.g. open links)"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var isEnabled: Bool = true

    /// CGEvent "other mouse" button number. 2 = middle button.
    var triggerButtonNumber: Int64 = 2

    /// What a quick tap (as opposed to a hold + drag) of the trigger
    /// button does. Defaults to the existing toggle-scroll behavior so
    /// nothing changes unless you opt in.
    var quickClickAction: QuickClickAction = .toggleScroll

    var deadZoneRadius: Double = 12.0
    var maxScrollSpeed: Double = 40.0

    /// Distance in points, past the dead zone, at which you reach max scroll
    /// speed. Smaller = you hit top speed with less movement (aggressive).
    /// Larger = you have to drag further before it maxes out (gradual).
    var maxSpeedDistance: Double = 100.0

    /// Shape of the ramp between the dead zone and maxSpeedDistance.
    /// 1.0 = linear. <1 = ramps up quickly then levels off. >1 = starts
    /// slow and rushes toward the end. Keep this modest — pow() on a 0...1
    /// value collapses to ~0 for most of the range once the exponent gets
    /// much above ~4, which is what caused the old "glitchy" slider.
    var accelerationExponent: Double = 1.4

    var axisLock: AxisLock = .both
    var invertVertical: Bool = false
    var invertHorizontal: Bool = false

    var showCursorOverlay: Bool = true
    var excludedBundleIDs: [String] = []
    var launchAtLogin: Bool = false
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let defaultsKey = "com.example.autoscroll.settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
