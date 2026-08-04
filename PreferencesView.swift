// PreferencesView.swift
// The customization panel — the other must-have feature.

import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var newExcludedID: String = ""

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable AutoScroll", isOn: $store.settings.isEnabled)
                Toggle("Show custom cursor icon", isOn: $store.settings.showCursorOverlay)
                Toggle("Launch at login", isOn: $store.settings.launchAtLogin)
                    .onChange(of: store.settings.launchAtLogin) { newValue in
                        LoginItemManager.setEnabled(newValue)
                    }
            }

            Section("Trigger") {
                Picker("Trigger button", selection: $store.settings.triggerButtonNumber) {
                    Text("Middle button").tag(Int64(2))
                    Text("Mouse button 4").tag(Int64(3))
                    Text("Mouse button 5").tag(Int64(4))
                }
                Text("Button numbering beyond the middle button depends on your mouse/driver.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Quick click", selection: $store.settings.quickClickAction) {
                    ForEach(QuickClickAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                Text("\"Act as a normal click\" lets a quick middle-click still open links etc. — only a hold + drag will scroll.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Scrolling") {
                HStack {
                    Text("Dead zone")
                    Slider(value: $store.settings.deadZoneRadius, in: 4...40)
                    Text("\(Int(store.settings.deadZoneRadius))px").monospacedDigit()
                }
                HStack {
                    Text("Max speed")
                    Slider(value: $store.settings.maxScrollSpeed, in: 5...120)
                    Text("\(Int(store.settings.maxScrollSpeed))").monospacedDigit()
                }
                HStack {
                    Text("Distance to max speed")
                    Slider(value: $store.settings.maxSpeedDistance, in: 20...400)
                    Text("\(Int(store.settings.maxSpeedDistance))px").monospacedDigit()
                }
                Text("How far past the dead zone you need to drag before you hit top speed. Lower = faster ramp-up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Acceleration curve")
                    Slider(value: $store.settings.accelerationExponent, in: 0.5...4.0)
                    Text(String(format: "%.1f", store.settings.accelerationExponent)).monospacedDigit()
                }
                Picker("Axis lock", selection: $store.settings.axisLock) {
                    ForEach(AxisLock.allCases) { axis in
                        Text(axis.label).tag(axis)
                    }
                }
                Toggle("Invert vertical", isOn: $store.settings.invertVertical)
                Toggle("Invert horizontal", isOn: $store.settings.invertHorizontal)
            }

            Section("Excluded apps") {
                ForEach(store.settings.excludedBundleIDs, id: \.self) { id in
                    HStack {
                        Text(id)
                        Spacer()
                        Button(role: .destructive) {
                            store.settings.excludedBundleIDs.removeAll { $0 == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("com.example.app", text: $newExcludedID)
                    Button("Add") {
                        let trimmed = newExcludedID.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.settings.excludedBundleIDs.append(trimmed)
                        newExcludedID = ""
                    }
                }
            }
        }
        .padding()
        .frame(width: 420)
    }
}
