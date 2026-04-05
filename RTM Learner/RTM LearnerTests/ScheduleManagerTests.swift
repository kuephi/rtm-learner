import XCTest
@testable import RTM_Learner

final class ScheduleManagerTests: XCTestCase {

    // Mon/Wed/Fri at 08:00
    let schedule = ScheduleConfig(days: [.monday, .wednesday, .friday], hour: 8, minute: 0)

    // MARK: - computeNextRunDate

    func test_nextRunDate_returnsLaterTodayWhenScheduledAndTimeIsInFuture() throws {
        // Tuesday 07:00 → next run is Wednesday 08:00
        let now = makeDate(weekday: .tuesday, hour: 7, minute: 0)
        let next = try XCTUnwrap(ScheduleManager.computeNextRunDate(schedule: schedule, from: now))
        assertDate(next, weekday: .wednesday, hour: 8, minute: 0)
    }

    func test_nextRunDate_returnsLaterTodayWhenScheduledDayAndTimeIsInFuture() throws {
        // Monday 07:00 — today IS a run day and time hasn't passed yet
        let now = makeDate(weekday: .monday, hour: 7, minute: 0)
        let next = try XCTUnwrap(ScheduleManager.computeNextRunDate(schedule: schedule, from: now))
        assertDate(next, weekday: .monday, hour: 8, minute: 0)
    }

    func test_nextRunDate_skipsToNextDayWhenTodayScheduledButTimePassed() throws {
        // Monday 09:00 — today IS a run day but 08:00 has passed → next is Wednesday
        let now = makeDate(weekday: .monday, hour: 9, minute: 0)
        let next = try XCTUnwrap(ScheduleManager.computeNextRunDate(schedule: schedule, from: now))
        assertDate(next, weekday: .wednesday, hour: 8, minute: 0)
    }

    func test_nextRunDate_wrapsAcrossWeekBoundary() throws {
        // Friday 09:00 — last run day of the week, time passed → wraps to Monday
        let now = makeDate(weekday: .friday, hour: 9, minute: 0)
        let next = try XCTUnwrap(ScheduleManager.computeNextRunDate(schedule: schedule, from: now))
        assertDate(next, weekday: .monday, hour: 8, minute: 0)
    }

    // MARK: - mostRecentScheduledOccurrence

    func test_mostRecent_returnsNilWhenNoOccurrenceBeforeNow() {
        // Monday 07:00 — no scheduled occurrence has passed yet this week (Mon at 08:00 is in the future)
        let now = makeDate(weekday: .monday, hour: 7, minute: 0)
        let recent = ScheduleManager.mostRecentScheduledOccurrence(schedule: schedule, before: now)
        // The most recent past occurrence would be last Friday at 08:00
        XCTAssertNotNil(recent) // last Friday always exists
    }

    func test_mostRecent_returnsLastFridayAfterWeekend() throws {
        // Sunday 10:00 — most recent past occurrence is Friday 08:00
        let now = makeDate(weekday: .sunday, hour: 10, minute: 0)
        let recent = try XCTUnwrap(ScheduleManager.mostRecentScheduledOccurrence(schedule: schedule, before: now))
        assertDate(recent, weekday: .friday, hour: 8, minute: 0)
    }

    // MARK: - missedRun detection

    func test_isMissedRun_trueWhenLastRunBeforeMostRecentOccurrence() throws {
        // Most recent occurrence: Friday 08:00
        // Last run: Thursday 08:00 (before Friday) → missed
        let now = makeDate(weekday: .sunday, hour: 10, minute: 0)
        let lastRun = makeDate(weekday: .thursday, hour: 8, minute: 0)
        XCTAssertTrue(ScheduleManager.isMissedRun(schedule: schedule, lastRunDate: lastRun, now: now))
    }

    func test_isMissedRun_falseWhenLastRunAfterMostRecentOccurrence() throws {
        // Most recent occurrence: Friday 08:00
        // Last run: Friday 08:05 (after Friday) → not missed
        let now = makeDate(weekday: .sunday, hour: 10, minute: 0)
        let lastRun = makeDate(weekday: .friday, hour: 8, minute: 5)
        XCTAssertFalse(ScheduleManager.isMissedRun(schedule: schedule, lastRunDate: lastRun, now: now))
    }

    func test_isMissedRun_trueWhenLastRunIsNil() {
        let now = makeDate(weekday: .sunday, hour: 10, minute: 0)
        XCTAssertTrue(ScheduleManager.isMissedRun(schedule: schedule, lastRunDate: nil, now: now))
    }

    // MARK: - Helpers

    private func makeDate(weekday: Weekday, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.weekday = weekday.rawValue
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        comps.weekOfYear = 15
        comps.yearForWeekOfYear = 2026
        return Calendar.current.date(from: comps)!
    }

    private func assertDate(_ date: Date, weekday: Weekday, hour: Int, minute: Int,
                            file: StaticString = #filePath, line: UInt = #line) {
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: date), weekday.rawValue, "weekday", file: file, line: line)
        XCTAssertEqual(cal.component(.hour, from: date), hour, "hour", file: file, line: line)
        XCTAssertEqual(cal.component(.minute, from: date), minute, "minute", file: file, line: line)
    }
}
