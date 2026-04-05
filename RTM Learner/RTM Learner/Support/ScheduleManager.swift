import Foundation

@MainActor
final class ScheduleManager {
    static let shared = ScheduleManager()

    private var timer: Timer?
    var onFire: (() async -> Void)?

    // MARK: - Timer management

    func start(schedule: ScheduleConfig, lastRunDate: Date?) {
        if Self.isMissedRun(schedule: schedule, lastRunDate: lastRunDate, now: Date()) {
            Task { await onFire?() }
        }
        scheduleNext(schedule: schedule)
    }

    func reschedule(schedule: ScheduleConfig) {
        timer?.invalidate()
        scheduleNext(schedule: schedule)
    }

    private func scheduleNext(schedule: ScheduleConfig) {
        guard let nextDate = Self.computeNextRunDate(schedule: schedule, from: Date()) else { return }
        let interval = nextDate.timeIntervalSinceNow
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.onFire?()
                self?.scheduleNext(schedule: schedule)
            }
        }
    }

    // MARK: - Pure computation (nonisolated static, testable from any context)

    /// Returns the next `Date` on which the pipeline should run, or nil if the schedule has no days.
    nonisolated static func computeNextRunDate(schedule: ScheduleConfig, from now: Date) -> Date? {
        guard !schedule.days.isEmpty else { return nil }
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)
        let nowHour = cal.component(.hour, from: now)
        let nowMinute = cal.component(.minute, from: now)
        let scheduledHasPassed = (nowHour, nowMinute) >= (schedule.hour, schedule.minute)

        // Check the next 8 days (guarantees we wrap the full week)
        for daysAhead in 0..<8 {
            guard let candidate = cal.date(byAdding: .day, value: daysAhead, to: now) else { continue }
            let candidateWeekday = cal.component(.weekday, from: candidate)
            guard schedule.days.contains(Weekday(rawValue: candidateWeekday) ?? .monday) else { continue }
            if daysAhead == 0 && scheduledHasPassed { continue }
            return cal.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: candidate)
        }
        return nil
    }

    /// Returns the most recent past scheduled occurrence before `now`, or nil if the
    /// schedule is empty or no occurrence has ever happened.
    nonisolated static func mostRecentScheduledOccurrence(schedule: ScheduleConfig, before now: Date) -> Date? {
        guard !schedule.days.isEmpty else { return nil }
        let cal = Calendar.current

        for daysBack in 0..<8 {
            guard let candidate = cal.date(byAdding: .day, value: -daysBack, to: now) else { continue }
            let candidateWeekday = cal.component(.weekday, from: candidate)
            guard schedule.days.contains(Weekday(rawValue: candidateWeekday) ?? .monday) else { continue }
            guard let occurrence = cal.date(bySettingHour: schedule.hour, minute: schedule.minute,
                                           second: 0, of: candidate) else { continue }
            if occurrence < now { return occurrence }
        }
        return nil
    }

    /// Returns true if a scheduled run was missed (i.e. the last run pre-dates the most recent occurrence).
    nonisolated static func isMissedRun(schedule: ScheduleConfig, lastRunDate: Date?, now: Date) -> Bool {
        guard let mostRecent = mostRecentScheduledOccurrence(schedule: schedule, before: now) else {
            return false
        }
        guard let last = lastRunDate else { return true }
        return last < mostRecent
    }
}
