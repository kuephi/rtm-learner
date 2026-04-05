import SwiftUI
import ServiceManagement

struct ScheduleView: View {
    let settings: Settings
    @State private var launchAtLogin = false

    private let orderedDays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        Form {
            Section("Run on these days") {
                HStack(spacing: 8) {
                    ForEach(orderedDays) { day in
                        DayCircle(
                            label: day.shortName,
                            selected: settings.schedule.days.contains(day)
                        ) {
                            toggleDay(day)
                        }
                        .accessibilityIdentifier("day-\(day.rawValue)")
                    }
                }
            }

            Section("Time") {
                HStack {
                    Stepper(
                        value: Binding(
                            get: { settings.schedule.hour },
                            set: { settings.schedule.hour = $0 }
                        ),
                        in: 0...23
                    ) {
                        Text(String(format: "%02d:%02d", settings.schedule.hour, settings.schedule.minute))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 60)
                    }
                    .accessibilityIdentifier("stepper-hour")
                    Text("hour")
                        .foregroundStyle(.secondary)

                    Stepper(
                        value: Binding(
                            get: { settings.schedule.minute },
                            set: { settings.schedule.minute = $0 }
                        ),
                        in: 0...59,
                        step: 5
                    ) {
                        EmptyView()
                    }
                    .accessibilityIdentifier("stepper-minute")
                    Text("minute")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .onChange(of: settings.schedule) { _, _ in
            ScheduleManager.shared.reschedule(schedule: settings.schedule)
        }
    }

    private func toggleDay(_ day: Weekday) {
        var days = settings.schedule.days
        if days.contains(day) {
            guard days.count > 1 else { return } // at least one day must remain
            days.remove(day)
        } else {
            days.insert(day)
        }
        settings.schedule.days = days
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("SMAppService error: \(error)")
        }
    }
}

private struct DayCircle: View {
    let label: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(selected ? .white : .secondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "selected" : "unselected")
    }
}
