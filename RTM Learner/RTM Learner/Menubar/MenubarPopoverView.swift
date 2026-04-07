import SwiftUI

struct MenubarPopoverView: View {
    let settings: Settings
    let appLog: AppLog
    let onRunNow: () -> Void
    let onShowLog: () -> Void
    let onPreferences: () -> Void

    @State private var lastRunText: String = "Never"
    @State private var nextRunText: String = "—"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("RTM Learner")
                    .font(.headline)
                Spacer()
            }
            .padding([.top, .horizontal])

            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text(lastRunText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Next: \(nextRunText)")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text(scheduleDescription)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Actions
            VStack(spacing: 0) {
                popoverButton(
                    appLog.isPipelineRunning ? "⏳  Running…" : "▶  Run Now",
                    action: appLog.isPipelineRunning ? {} : onRunNow
                )
                .disabled(appLog.isPipelineRunning)
                popoverButton("📋  Show Log", action: onShowLog)
                popoverButton("⚙  Preferences…", action: onPreferences)
                Divider()
                popoverButton("Quit", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
        .onAppear(perform: updateDates)
    }

    private func popoverButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private var scheduleDescription: String {
        let days = Weekday.allCases
            .filter { settings.schedule.days.contains($0) }
            .map { $0.displayName }
            .joined(separator: " · ")
        let time = String(format: "%02d:%02d", settings.schedule.hour, settings.schedule.minute)
        return "\(days) at \(time)"
    }

    private func updateDates() {
        Task {
            let last = await StateManager.shared.lastRunDate
            if let last {
                lastRunText = "Last: \(DateFormatter.localizedString(from: last, dateStyle: .short, timeStyle: .short))"
            } else {
                lastRunText = "Never run"
            }
            if let next = ScheduleManager.computeNextRunDate(schedule: settings.schedule, from: Date()) {
                nextRunText = DateFormatter.localizedString(from: next, dateStyle: .short, timeStyle: .short)
            }
        }
    }
}
