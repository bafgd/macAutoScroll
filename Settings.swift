// Persisted, customizable settings.

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

// Internal state machine for the event tap, not persisted
enum ScrollMode {
    case idle
    case holdDrag
    case clickToggle
}

enum QuickClickAction: String, Codable, CaseIterable, Identifiable {
    case toggleScroll
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

    // CGEvent "other mouse" button number, 2 = middle button
    var triggerButtonNumber: Int64 = 2

    var quickClickAction: QuickClickAction = .toggleScroll

    var deadZoneRadius: Double = 12.0
    var maxScrollSpeed: Double = 40.0

    // distance past the dead zone at which max scroll speed is reached
    var maxSpeedDistance: Double = 100.0

    // shape of the ramp between dead zone and maxSpeedDistance;
    // 1.0 = linear, <1 ramps up fast then levels off, >1 starts slow
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
