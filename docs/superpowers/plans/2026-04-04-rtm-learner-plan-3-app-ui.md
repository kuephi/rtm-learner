# RTM Learner — Plan 3: App, UI & Distribution

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the pipeline into a menubar macOS app with a SwiftUI popover, a four-tab Preferences window (Schedule, Provider, Auth, Log), a smart scheduler with missed-run detection, and package it as a Homebrew cask.

**Architecture:** `AppDelegate` owns the `NSStatusBar` item. `ScheduleManager` computes `nextRunDate` exactly and fires a single `Timer` per run. All SwiftUI views read from a shared `Settings` instance injected via the environment. The app has no Dock icon (`LSUIElement = true`).

**Tech Stack:** Swift 5.9+, macOS 13.0+, SwiftUI, AppKit (NSStatusBar), SMAppService, XCTest

**Prerequisites:** Plans 1 and 2 complete (all models, providers, and pipeline steps exist).

**Spec:** `docs/superpowers/specs/2026-04-04-rtm-learner-macos-app-design.md`

---

## File Map

| File | Responsibility |
|------|---------------|
| `RTMLearner/App/RTMLearnerApp.swift` | App entry point, `LSUIElement`, injects `Settings` env object |
| `RTMLearner/App/AppDelegate.swift` | `NSStatusBar` item, popover, `ScheduleManager` ownership |
| `RTMLearner/Menubar/MenubarController.swift` | Shows/hides `NSPopover`, handles click |
| `RTMLearner/Menubar/MenubarPopoverView.swift` | SwiftUI popover content |
| `RTMLearner/Support/AppLog.swift` | `@Observable` log store — written by pipeline, observed by `LogView` |
| `RTMLearner/Support/ScheduleManager.swift` | `computeNextRunDate`, missed-run detection, `Timer` |
| `RTMLearner/Preferences/PreferencesWindowController.swift` | Creates and shows the `NSWindow` |
| `RTMLearner/Preferences/PreferencesView.swift` | `NavigationSplitView` shell |
| `RTMLearner/Preferences/ScheduleView.swift` | Day circles + time picker + login-item toggle |
| `RTMLearner/Preferences/ProviderView.swift` | Provider picker + API key + model selection |
| `RTMLearner/Preferences/AuthView.swift` | Substack credentials + session status |
| `RTMLearner/Preferences/LogView.swift` | Scrollable log output |
| `RTMLearnerTests/ScheduleManagerTests.swift` | `computeNextRunDate`, `mostRecentScheduledOccurrence` |

---

## Task 1: ScheduleManager

**Files:**
- Create: `RTMLearner/RTMLearner/Support/ScheduleManager.swift`
- Create: `RTMLearner/RTMLearnerTests/ScheduleManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/ScheduleManagerTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

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
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'ScheduleManager'".

- [ ] **Step 3: Implement ScheduleManager**

  Create `RTMLearner/Support/ScheduleManager.swift`:

  ```swift
  import Foundation

  @MainActor
  final class ScheduleManager {
      static let shared = ScheduleManager()

      private var timer: Timer?
      var onFire: (() async -> Void)?

      // MARK: - Timer management

      func start(schedule: ScheduleConfig, lastRunDate: Date?) {
          if isMissedRun(schedule: schedule, lastRunDate: lastRunDate, now: Date()) {
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

      // MARK: - Pure computation (static, testable without MainActor)

      /// Returns the next `Date` on which the pipeline should run, or nil if the schedule has no days.
      static func computeNextRunDate(schedule: ScheduleConfig, from now: Date) -> Date? {
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
      static func mostRecentScheduledOccurrence(schedule: ScheduleConfig, before now: Date) -> Date? {
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
      static func isMissedRun(schedule: ScheduleConfig, lastRunDate: Date?, now: Date) -> Bool {
          guard let mostRecent = mostRecentScheduledOccurrence(schedule: schedule, before: now) else {
              return false
          }
          guard let last = lastRunDate else { return true }
          return last < mostRecent
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all ScheduleManager tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add ScheduleManager — exact-fire timer with missed-run detection"
  ```

---

## Task 2: App Entry Point

**Files:**
- Modify: `RTMLearner/RTMLearner/RTMLearnerApp.swift` (replace generated content)
- Create: `RTMLearner/RTMLearner/App/AppDelegate.swift`

- [ ] **Step 1: Configure LSUIElement (no Dock icon)**

  Open `Info.plist` (in the RTMLearner target). Add:
  ```
  Key:   Application is agent (UIElement)
  Type:  Boolean
  Value: YES
  ```

  Or add to `Info.plist` as XML:
  ```xml
  <key>LSUIElement</key>
  <true/>
  ```

- [ ] **Step 2: Replace RTMLearnerApp.swift**

  Replace the generated `RTMLearnerApp.swift` entirely:

  ```swift
  import SwiftUI

  @main
  struct RTMLearnerApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

      var body: some Scene {
          // No WindowGroup — this is a menubar-only app.
          // All windows are created programmatically by AppDelegate.
          Settings { EmptyView() }
      }
  }
  ```

- [ ] **Step 3: Create AppDelegate**

  Create `RTMLearner/App/AppDelegate.swift`:

  ```swift
  import AppKit
  import SwiftUI

  final class AppDelegate: NSObject, NSApplicationDelegate {

      let settings = Settings()
      let appLog = AppLog()
      private var menubarController: MenubarController?
      private var preferencesController: PreferencesWindowController?

      func applicationDidFinishLaunching(_ notification: Notification) {
          menubarController = MenubarController(
              settings: settings,
              appLog: appLog,
              openPreferences: { [weak self] in self?.openPreferences() }
          )

          Task { @MainActor in
              ScheduleManager.shared.onFire = { [weak self] in
                  await self?.runPipeline()
              }
              ScheduleManager.shared.start(
                  schedule: settings.schedule,
                  lastRunDate: await StateManager.shared.lastRunDate
              )
          }
      }

      func openPreferences() {
          if preferencesController == nil {
              preferencesController = PreferencesWindowController(settings: settings, appLog: appLog)
          }
          preferencesController?.showWindow(nil)
          NSApp.activate(ignoringOtherApps: true)
      }

      @MainActor
      func runPipeline() async {
          guard let sessionCookie = try? KeychainHelper.load(for: "substack_session") else {
              appLog.append("Pipeline failed: Substack session cookie missing. Add it in Preferences → Auth.")
              return
          }

          let provider: LLMProvider
          do {
              provider = try ProviderFactory.make(settings: settings)
          } catch {
              appLog.append("Pipeline failed: \(error.localizedDescription)")
              return
          }

          let outputDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
              .appendingPathComponent("RTMLearner")
          let iCloudDir = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/RTM")

          let stateManager = StateManager.shared
          let http: HTTPClient = URLSession.shared

          do {
              let entries = try await Fetcher.fetchNewEntries(stateManager: stateManager)
              if entries.isEmpty {
                  appLog.append("No new 中级 episodes found.")
                  return
              }
              for entry in entries {
                  appLog.append("\n→ Episode #\(entry.episode): \(entry.title)")
                  let pageURL = URL(string: entry.url)!
                  let html = try await Fetcher.downloadPage(url: pageURL, sessionCookie: sessionCookie, http: http)
                  try await PipelineRunner.run(
                      entry: entry, html: html,
                      provider: provider,
                      stateManager: stateManager,
                      outputDir: outputDir,
                      iCloudDir: iCloudDir,
                      log: { [weak self] msg in self?.appLog.append(msg) }
                  )
              }
          } catch {
              appLog.append("Pipeline error: \(error.localizedDescription)")
          }
      }
  }
  ```

- [ ] **Step 4: Build — expect success**

  `Cmd+B`. Expected: Build Succeeded (MenubarController, PreferencesWindowController don't exist yet — add empty stubs):

  Create `RTMLearner/Menubar/MenubarController.swift` with a stub:
  ```swift
  import AppKit
  import SwiftUI

  @MainActor
  final class MenubarController {
      init(settings: Settings, appLog: AppLog, openPreferences: @escaping () -> Void) {}
  }
  ```

  Create `RTMLearner/Support/AppLog.swift`:
  ```swift
  import Foundation
  import Observation

  @Observable
  final class AppLog {
      var text: String = ""

      func append(_ message: String) {
          let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
          text += "[\(timestamp)] \(message)\n"
      }

      func clear() {
          text = ""
      }
  }
  ```

  Create `RTMLearner/Preferences/PreferencesWindowController.swift` with a stub:
  ```swift
  import AppKit
  final class PreferencesWindowController: NSWindowController {
      init(settings: Settings, appLog: AppLog) { super.init(window: nil) }
      required init?(coder: NSCoder) { fatalError() }
  }
  ```

  `Cmd+B` again. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: app entry point — menubar-only, LSUIElement, AppDelegate wiring"
  ```

---

## Task 3: MenubarController + Popover

**Files:**
- Modify: `RTMLearner/RTMLearner/Menubar/MenubarController.swift` (replace stub)
- Create: `RTMLearner/RTMLearner/Menubar/MenubarPopoverView.swift`

- [ ] **Step 1: Implement MenubarController**

  Replace `RTMLearner/Menubar/MenubarController.swift`:

  ```swift
  import AppKit
  import SwiftUI

  @MainActor
  final class MenubarController {
      private var statusItem: NSStatusItem!
      private var popover: NSPopover!
      private let settings: Settings
      private let appLog: AppLog
      private let openPreferences: () -> Void

      init(settings: Settings, appLog: AppLog, openPreferences: @escaping () -> Void) {
          self.settings = settings
          self.appLog = appLog
          self.openPreferences = openPreferences
          setupStatusItem()
          setupPopover()
      }

      private func setupStatusItem() {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          if let button = statusItem.button {
              button.title = "RTM"
              button.action = #selector(togglePopover)
              button.target = self
          }
      }

      private func setupPopover() {
          popover = NSPopover()
          popover.contentSize = NSSize(width: 260, height: 280)
          popover.behavior = .transient
          popover.contentViewController = NSHostingController(
              rootView: MenubarPopoverView(
                  settings: settings,
                  onRunNow: {
                      Task { @MainActor in
                          await (NSApp.delegate as? AppDelegate)?.runPipeline()
                      }
                  },
                  onShowLog: { [weak self] in
                      self?.openPreferences()
                  },
                  onPreferences: { [weak self] in
                      self?.openPreferences()
                  }
              )
          )
      }

      @objc private func togglePopover() {
          guard let button = statusItem.button else { return }
          if popover.isShown {
              popover.performClose(nil)
          } else {
              popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
          }
      }
  }
  ```

- [ ] **Step 2: Implement MenubarPopoverView**

  Create `RTMLearner/Menubar/MenubarPopoverView.swift`:

  ```swift
  import SwiftUI

  struct MenubarPopoverView: View {
      let settings: Settings
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
                  popoverButton("▶  Run Now", action: onRunNow)
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
          }
          if let next = ScheduleManager.computeNextRunDate(schedule: settings.schedule, from: Date()) {
              nextRunText = DateFormatter.localizedString(from: next, dateStyle: .short, timeStyle: .short)
          }
      }
  }
  ```

- [ ] **Step 3: Build — expect success**

  `Cmd+B`. Expected: Build Succeeded.

- [ ] **Step 4: Smoke test the menubar icon**

  Run the app (`Cmd+R`). Expected:
  - No Dock icon appears
  - "RTM" appears in the macOS menu bar
  - Clicking it opens the popover with status + buttons

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: menubar icon and popover with status, run-now, and quit"
  ```

---

## Task 4: Preferences Window Shell

**Files:**
- Modify: `RTMLearner/RTMLearner/Preferences/PreferencesWindowController.swift` (replace stub)
- Create: `RTMLearner/RTMLearner/Preferences/PreferencesView.swift`

- [ ] **Step 1: Implement PreferencesWindowController**

  Replace `RTMLearner/Preferences/PreferencesWindowController.swift`:

  ```swift
  import AppKit
  import SwiftUI

  final class PreferencesWindowController: NSWindowController {
      private let settings: Settings
      private let appLog: AppLog

      init(settings: Settings, appLog: AppLog) {
          self.settings = settings
          self.appLog = appLog
          let window = NSWindow(
              contentRect: NSRect(x: 0, y: 0, width: 580, height: 400),
              styleMask: [.titled, .closable, .miniaturizable],
              backing: .buffered,
              defer: false
          )
          window.title = "RTM Learner Preferences"
          window.center()
          window.contentView = NSHostingView(rootView: PreferencesView(settings: settings, appLog: appLog))
          super.init(window: window)
      }

      required init?(coder: NSCoder) { fatalError() }

      override func showWindow(_ sender: Any?) {
          super.showWindow(sender)
          window?.makeKeyAndOrderFront(sender)
      }
  }
  ```

- [ ] **Step 2: Implement PreferencesView**

  Create `RTMLearner/Preferences/PreferencesView.swift`:

  ```swift
  import SwiftUI

  enum PreferencesSection: String, CaseIterable, Identifiable {
      case schedule = "Schedule"
      case provider = "Provider"
      case auth     = "Auth"
      case log      = "Log"

      var id: String { rawValue }

      var icon: String {
          switch self {
          case .schedule: return "clock"
          case .provider: return "cpu"
          case .auth:     return "key"
          case .log:      return "doc.text"
          }
      }
  }

  struct PreferencesView: View {
      let settings: Settings
      let appLog: AppLog
      @State private var selection: PreferencesSection = .schedule

      var body: some View {
          NavigationSplitView {
              List(PreferencesSection.allCases, selection: $selection) { section in
                  Label(section.rawValue, systemImage: section.icon)
                      .tag(section)
              }
              .navigationSplitViewColumnWidth(min: 140, ideal: 160)
          } detail: {
              switch selection {
              case .schedule: ScheduleView(settings: settings)
              case .provider: ProviderView(settings: settings)
              case .auth:     AuthView()
              case .log:      LogView(appLog: appLog)
              }
          }
          .frame(minWidth: 540, minHeight: 360)
      }
  }
  ```

- [ ] **Step 3: Add placeholder detail views**

  Create `RTMLearner/Preferences/ScheduleView.swift` with a stub:
  ```swift
  import SwiftUI
  struct ScheduleView: View {
      let settings: Settings
      var body: some View { Text("Schedule — coming in Task 5") }
  }
  ```

  Create `RTMLearner/Preferences/ProviderView.swift` with a stub:
  ```swift
  import SwiftUI
  struct ProviderView: View {
      let settings: Settings
      var body: some View { Text("Provider — coming in Task 6") }
  }
  ```

  Create `RTMLearner/Preferences/AuthView.swift` with a stub:
  ```swift
  import SwiftUI
  struct AuthView: View {
      var body: some View { Text("Auth — coming in Task 7") }
  }
  ```

  Create `RTMLearner/Preferences/LogView.swift` with a stub:
  ```swift
  import SwiftUI
  struct LogView: View {
      let appLog: AppLog
      var body: some View { Text("Log — coming in Task 8") }
  }
  ```

- [ ] **Step 4: Build and smoke test**

  `Cmd+R`. Expected:
  - "Preferences…" in the popover opens a window
  - Sidebar shows Schedule / Provider / Auth / Log
  - Clicking each shows placeholder text

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: preferences window shell with NavigationSplitView sidebar"
  ```

---

## Task 5: ScheduleView

**Files:**
- Modify: `RTMLearner/RTMLearner/Preferences/ScheduleView.swift` (replace stub)

- [ ] **Step 1: Implement ScheduleView**

  Replace `RTMLearner/Preferences/ScheduleView.swift`:

  ```swift
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
      }
  }
  ```

- [ ] **Step 2: Build and smoke test**

  `Cmd+R`. Open Preferences → Schedule.
  Expected:
  - Seven day circles (M T W T F S S)
  - Pre-selected days show filled circles
  - Tapping toggles selection (minimum 1 day stays selected)
  - Steppers adjust hour and minute
  - "Launch at login" toggle works

- [ ] **Step 3: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: ScheduleView — day-of-week circles, time steppers, login item toggle"
  ```

---

## Task 6: ProviderView

**Files:**
- Modify: `RTMLearner/RTMLearner/Preferences/ProviderView.swift` (replace stub)

- [ ] **Step 1: Implement ProviderView**

  Replace `RTMLearner/Preferences/ProviderView.swift`:

  ```swift
  import SwiftUI

  struct ProviderView: View {
      let settings: Settings

      @State private var apiKey: String = ""
      @State private var openRouterModels: [OpenRouterProvider.Model] = []
      @State private var isFetchingModels = false
      @State private var modelFetchError: String? = nil

      var body: some View {
          Form {
              Section("LLM Provider") {
                  Picker("Provider", selection: $settings.providerType) {
                      ForEach(LLMProviderType.allCases) { type in
                          Text(type.displayName).tag(type)
                      }
                  }
                  .pickerStyle(.segmented)
                  .onChange(of: settings.providerType) { _, _ in loadApiKey() }
              }

              Section("API Key") {
                  SecureField("API Key", text: $apiKey)
                      .onChange(of: apiKey) { _, newKey in saveApiKey(newKey) }
              }

              if settings.providerType == .openrouter {
                  openRouterModelSection
              } else {
                  Section("Model Override (optional)") {
                      TextField(
                          settings.providerType.defaultModel ?? "model-id",
                          text: modelOverrideBinding
                      )
                      .font(.system(.body, design: .monospaced))
                      Text("Leave blank to use the default: \(settings.providerType.defaultModel ?? "—")")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
              }
          }
          .formStyle(.grouped)
          .onAppear(perform: loadApiKey)
      }

      // MARK: - OpenRouter Model Section

      private var openRouterModelSection: some View {
          Section {
              if isFetchingModels {
                  HStack { ProgressView(); Text("Fetching models…").foregroundStyle(.secondary) }
              } else if openRouterModels.isEmpty {
                  if let error = modelFetchError {
                      VStack(alignment: .leading) {
                          Text(error).foregroundStyle(.red).font(.caption)
                          TextField("Model ID (e.g. anthropic/claude-sonnet-4-6)",
                                    text: $settings.openRouterModel)
                              .font(.system(.body, design: .monospaced))
                      }
                  } else {
                      Button("Fetch available models") { Task { await fetchOpenRouterModels() } }
                  }
              } else {
                  Picker("Model", selection: $settings.openRouterModel) {
                      ForEach(openRouterModels) { model in
                          Text(model.name).tag(model.id)
                      }
                  }
                  Button("Refresh") { Task { await fetchOpenRouterModels() } }
              }
          } header: {
              Text("Model")
          }
      }

      // MARK: - Helpers

      private var modelOverrideBinding: Binding<String> {
          switch settings.providerType {
          case .claude:      return $settings.claudeModel
          case .gemini:      return $settings.geminiModel
          case .openai:      return $settings.openAIModel
          case .openrouter:  return $settings.openRouterModel
          }
      }

      private var keychainKey: String {
          "\(settings.providerType.rawValue)_api_key"
      }

      private func loadApiKey() {
          apiKey = (try? KeychainHelper.load(for: keychainKey)) ?? ""
          if settings.providerType == .openrouter && !apiKey.isEmpty && openRouterModels.isEmpty {
              Task { await fetchOpenRouterModels() }
          }
      }

      private func saveApiKey(_ key: String) {
          guard !key.isEmpty else { return }
          try? KeychainHelper.save(key, for: keychainKey)
      }

      private func fetchOpenRouterModels() async {
          guard let key = try? KeychainHelper.load(for: "openrouter_api_key") else {
              modelFetchError = "Enter your API key first."
              return
          }
          isFetchingModels = true
          modelFetchError = nil
          do {
              openRouterModels = try await OpenRouterProvider.fetchModels(apiKey: key)
              if settings.openRouterModel.isEmpty, let first = openRouterModels.first {
                  settings.openRouterModel = first.id
              }
          } catch {
              modelFetchError = "Could not fetch models: \(error.localizedDescription)"
              openRouterModels = []
          }
          isFetchingModels = false
      }
  }
  ```

- [ ] **Step 2: Build and smoke test**

  `Cmd+R`. Open Preferences → Provider.
  Expected:
  - Segmented control shows Claude / Gemini / OpenAI / OpenRouter
  - API key field is masked (SecureField)
  - For Claude/Gemini/OpenAI: shows optional model override text field
  - For OpenRouter: shows "Fetch available models" button → tapping fetches and shows a Picker

- [ ] **Step 3: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: ProviderView — provider picker, API key, OpenRouter model list"
  ```

---

## Task 7: AuthView

**Files:**
- Modify: `RTMLearner/RTMLearner/Preferences/AuthView.swift` (replace stub)

- [ ] **Step 1: Implement AuthView**

  Replace `RTMLearner/Preferences/AuthView.swift`:

  ```swift
  import SwiftUI

  struct AuthView: View {
      @State private var email: String = ""
      @State private var password: String = ""
      @State private var sessionCookie: String = ""
      @State private var sessionStatus: String = "Unknown"
      @State private var isRefreshing = false
      @State private var refreshError: String? = nil

      var body: some View {
          Form {
              Section("Substack Account") {
                  TextField("Email", text: $email)
                      .onChange(of: email) { _, v in try? KeychainHelper.save(v, for: "substack_email") }
                  SecureField("Password", text: $password)
                      .onChange(of: password) { _, v in try? KeychainHelper.save(v, for: "substack_password") }
              }

              Section {
                  HStack {
                      Text(sessionStatus)
                          .foregroundStyle(sessionStatus.contains("Active") ? .green : .orange)
                      Spacer()
                      Button(isRefreshing ? "Refreshing…" : "Refresh Session") {
                          Task { await refreshSession() }
                      }
                      .disabled(isRefreshing)
                  }
                  if let error = refreshError {
                      Text(error)
                          .font(.caption)
                          .foregroundStyle(.red)
                  }
              } header: {
                  Text("Session")
              } footer: {
                  Text("If automatic refresh fails (Substack may block API logins), paste your substack.sid cookie from browser DevTools below.")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }

              Section("Manual Cookie Fallback") {
                  SecureField("substack.sid value", text: $sessionCookie)
                      .font(.system(.body, design: .monospaced))
                  Button("Save Cookie") { saveCookieManually() }
                      .disabled(sessionCookie.isEmpty)
              }
          }
          .formStyle(.grouped)
          .onAppear(perform: loadCredentials)
      }

      private func loadCredentials() {
          email    = (try? KeychainHelper.load(for: "substack_email"))    ?? ""
          password = (try? KeychainHelper.load(for: "substack_password")) ?? ""
          updateSessionStatus()
      }

      private func updateSessionStatus() {
          if let _ = try? KeychainHelper.load(for: "substack_session") {
              sessionStatus = "Active (cookie present)"
          } else {
              sessionStatus = "No session cookie — refresh or paste manually"
          }
      }

      private func refreshSession() async {
          isRefreshing = true
          refreshError = nil
          do {
              let email    = try KeychainHelper.load(for: "substack_email")
              let password = try KeychainHelper.load(for: "substack_password")
              let cookie   = try await SubstackAuth.login(email: email, password: password)
              try KeychainHelper.save(cookie, for: "substack_session")
              updateSessionStatus()
          } catch SubstackAuthError.blocked {
              refreshError = "Substack blocked the API login. Paste your substack.sid cookie manually from browser DevTools (Application → Cookies → substack.com)."
          } catch {
              refreshError = error.localizedDescription
          }
          isRefreshing = false
      }

      private func saveCookieManually() {
          try? KeychainHelper.save(sessionCookie, for: "substack_session")
          sessionCookie = ""
          updateSessionStatus()
      }
  }
  ```

- [ ] **Step 2: Create SubstackAuth**

  Create `RTMLearner/Support/SubstackAuth.swift`:

  ```swift
  import Foundation

  enum SubstackAuthError: Error {
      case blocked
      case invalidCredentials
      case noCookieReturned
  }

  struct SubstackAuth {
      static func login(
          email: String,
          password: String,
          http: HTTPClient = URLSession.shared
      ) async throws -> String {
          var request = URLRequest(url: URL(string: "https://substack.com/api/v1/login")!)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("https://substack.com", forHTTPHeaderField: "Origin")
          request.setValue(
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
              forHTTPHeaderField: "User-Agent"
          )
          let body = ["email": email, "password": password, "captcha_response": nil as String?]
          request.httpBody = try JSONSerialization.data(withJSONObject: body)

          let (_, response) = try await http.data(for: request)
          guard let httpResponse = response as? HTTPURLResponse else {
              throw SubstackAuthError.noCookieReturned
          }
          if httpResponse.statusCode == 401 { throw SubstackAuthError.invalidCredentials }
          if httpResponse.statusCode == 403 { throw SubstackAuthError.blocked }
          guard (200..<300).contains(httpResponse.statusCode) else {
              throw SubstackAuthError.blocked
          }
          // Extract substack.sid from Set-Cookie header
          let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
          if let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url!).first(where: { $0.name == "substack.sid" }) {
              return cookies.value
          }
          throw SubstackAuthError.noCookieReturned
      }
  }
  ```

- [ ] **Step 3: Build and smoke test**

  `Cmd+R`. Open Preferences → Auth.
  Expected:
  - Email + password fields
  - Session status and Refresh button
  - Footer explains the manual fallback
  - Manual cookie paste field works

- [ ] **Step 4: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: AuthView — Substack credentials, session refresh, manual cookie fallback"
  ```

---

## Task 8: LogView

**Files:**
- Modify: `RTMLearner/RTMLearner/Preferences/LogView.swift` (replace stub)

- [ ] **Step 1: Implement LogView**

  Replace `RTMLearner/Preferences/LogView.swift`:

  ```swift
  import SwiftUI

  struct LogView: View {
      let appLog: AppLog

      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              HStack {
                  Text("Last Run Log")
                      .font(.headline)
                  Spacer()
                  Button("Clear") {
                      appLog.clear()
                  }
              }
              .padding()

              Divider()

              ScrollViewReader { proxy in
                  ScrollView {
                      Text(appLog.text.isEmpty ? "(no log yet)" : appLog.text)
                          .font(.system(.caption, design: .monospaced))
                          .frame(maxWidth: .infinity, alignment: .leading)
                          .padding()
                          .id("logBottom")
                  }
                  .onChange(of: appLog.text) { _, _ in
                      proxy.scrollTo("logBottom", anchor: .bottom)
                  }
              }
          }
      }
  }
  ```

  Because `AppLog` is `@Observable`, SwiftUI automatically tracks access to `appLog.text` and re-renders when it changes. No `@State` or `@ObservedObject` wrapper needed.

- [ ] **Step 2: Build and smoke test**

  `Cmd+R`. Run Now → open Preferences → Log.
  Expected: log output scrolls to bottom, Clear button empties it.

- [ ] **Step 3: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: LogView — scrollable monospaced log output with clear button"
  ```

---

## Task 9: Remove Python Files

**Files:** delete the retired Python project files

- [ ] **Step 1: Remove Python source and tooling**

  ```bash
  cd /Users/kuephi/projects/learn/chinese
  git rm main.py fetcher.py parser.py translator.py auth.py config.py
  git rm -r exporters/
  git rm -r launchd/
  git rm run.sh
  git rm requirements.txt pytest.ini
  git rm -r tests/
  ```

- [ ] **Step 2: Keep data/ directory but ignore its contents**

  The `data/episodes/` JSON files remain valid — same schema. They stay on disk but are already gitignored.

- [ ] **Step 3: Update CLAUDE.md**

  Replace the content of `CLAUDE.md`:

  ```markdown
  # CLAUDE.md

  ## Project

  RTM Learner is a native Swift/SwiftUI macOS menubar app. It fetches RTM Mandarin
  intermediate (中级) lessons, parses them with an LLM, translates vocabulary to German,
  and exports Pleco flashcard files to iCloud Drive.

  ## Xcode project

  Open `RTMLearner/RTMLearner.xcodeproj` in Xcode.

  - Minimum deployment: macOS 13.0
  - Swift packages: FeedKit, SwiftSoup (resolved automatically)
  - Run tests: Cmd+U
  - Run app: Cmd+R

  ## Architecture

  See `docs/superpowers/specs/2026-04-04-rtm-learner-macos-app-design.md`

  ## Distribution

  See Plan 3 Task 10 in `docs/superpowers/plans/`.
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add CLAUDE.md
  git commit -m "chore: remove retired Python pipeline, update CLAUDE.md"
  ```

---

## Task 10: Distribution — Homebrew Cask

**Files:**
- GitHub: create a Release in the source repo
- GitHub: create `kuephi/homebrew-tools` repo with a cask formula

- [ ] **Step 1: Archive and sign the app in Xcode**

  In Xcode: Product → Archive

  Then in the Organizer:
  - Click "Distribute App"
  - Choose "Direct Distribution"
  - Click "Export" — saves `RTMLearner.app` to disk

  If you don't have a paid Apple Developer account, skip signing and export directly:
  - Product → Build → find the app in `~/Library/Developer/Xcode/DerivedData/.../RTMLearner.app`

  **For unsigned distribution (personal use only):** users must run:
  ```bash
  xattr -cr /Applications/RTMLearner.app
  ```
  before first launch to bypass Gatekeeper.

- [ ] **Step 2: Create a zip and compute SHA256**

  ```bash
  cd ~/path/to/exported/
  ditto -c -k --keepParent RTMLearner.app RTMLearner.zip
  shasum -a 256 RTMLearner.zip
  ```

  Note the SHA256 hash — you'll need it in the formula.

- [ ] **Step 3: Create a GitHub Release**

  In the source repo on GitHub:
  - Tag: `v1.0.0`
  - Title: "RTM Learner v1.0.0"
  - Upload `RTMLearner.zip` as a release asset

  Note the download URL — format:
  ```
  https://github.com/kuephi/<repo>/releases/download/v1.0.0/RTMLearner.zip
  ```

- [ ] **Step 4: Create the Homebrew tap repo**

  On GitHub: create a new public repo named `homebrew-tools`.

  Clone it locally and create the cask formula:

  ```bash
  mkdir -p Casks
  ```

  Create `Casks/rtm-learner.rb`:
  ```ruby
  cask "rtm-learner" do
    version "1.0.0"
    sha256 "PASTE_SHA256_HERE"

    url "https://github.com/kuephi/REPO/releases/download/v#{version}/RTMLearner.zip"
    name "RTM Learner"
    desc "macOS menubar app for RTM Mandarin lesson pipeline"
    homepage "https://github.com/kuephi/REPO"

    app "RTMLearner.app"

    zap trash: [
      "~/Library/Application Support/RTMLearner",
      "~/Library/Preferences/com.kuephi.rtm-learner.plist",
    ]
  end
  ```

  Replace `PASTE_SHA256_HERE` with the hash from Step 2, and `REPO` with the actual repo name.

  ```bash
  git add Casks/rtm-learner.rb
  git commit -m "feat: add rtm-learner cask v1.0.0"
  git push
  ```

- [ ] **Step 5: Test the install**

  ```bash
  brew tap kuephi/tools
  brew install --cask rtm-learner
  ```

  Expected: app downloads, installs to `/Applications/RTMLearner.app`, opens from Spotlight.

- [ ] **Step 6: Commit updated CLAUDE.md with install instructions**

  Add install instructions to `CLAUDE.md`:

  ```markdown
  ## Install

  ```bash
  brew tap kuephi/tools
  brew install --cask rtm-learner
  ```
  ```

  ```bash
  git add CLAUDE.md
  git commit -m "docs: add Homebrew install instructions to CLAUDE.md"
  ```

---

## Plan 3 Complete

The full RTM Learner macOS app is built, wired together, and distributable via Homebrew.

Run the full test suite one final time:
```
Cmd+U — expect: all tests PASS, 0 failures
```

**End-to-end smoke test checklist:**
- [ ] App launches with no Dock icon
- [ ] Menubar icon "RTM" is visible
- [ ] Clicking icon shows popover with status + next run time
- [ ] "Preferences…" opens sidebar window
- [ ] Schedule: day circles toggle, time steps update, login toggle persists
- [ ] Provider: switching providers updates API key field, OpenRouter fetches model list
- [ ] Auth: credentials saved to Keychain, manual cookie paste works
- [ ] Log: "Run Now" produces log output, Clear empties it
- [ ] "Run Now" with valid credentials runs the full pipeline end-to-end
- [ ] App added to Login Items → survives logout/login
