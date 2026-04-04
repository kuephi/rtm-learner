# RTM Learner — Plan 1: Foundation & Models

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the Xcode project and all non-network foundation code: data models, JSON repair, Keychain helper, UserDefaults settings wrapper, and on-disk state manager — all fully tested with XCTest.

**Architecture:** Pure Swift value types and actors. No UI, no network. Every type is independently testable. Plan 2 (providers + pipeline) and Plan 3 (app + UI) both depend on this plan completing first.

**Tech Stack:** Swift 5.9+, macOS 13.0+, XCTest, Foundation, Security framework

**Spec:** `docs/superpowers/specs/2026-04-04-rtm-learner-macos-app-design.md`

---

## File Map

| File | Responsibility |
|------|---------------|
| `RTMLearner/Models/Episode.swift` | `Episode`, `Word`, `DialogueLine`, `GrammarPattern`, `Exercise` — Codable structs matching the existing JSON schema |
| `RTMLearner/Models/ScheduleConfig.swift` | `Weekday` enum, `ScheduleConfig` struct |
| `RTMLearner/Models/LLMProviderType.swift` | `LLMProviderType` enum with display names and default models |
| `RTMLearner/Support/JSONRepair.swift` | Strip markdown fences, repair truncated JSON |
| `RTMLearner/Support/KeychainHelper.swift` | Save/load/delete strings from the macOS Keychain |
| `RTMLearner/Support/Settings.swift` | `@Observable` UserDefaults wrapper for all app settings |
| `RTMLearner/Support/StateManager.swift` | `actor` — persist processed URLs and last run date in Application Support |
| `RTMLearnerTests/ModelTests.swift` | Encode/decode round-trips for all Codable types |
| `RTMLearnerTests/JSONRepairTests.swift` | Fence stripping, truncation repair |
| `RTMLearnerTests/KeychainHelperTests.swift` | Save/load/delete/missing-key behaviour |
| `RTMLearnerTests/SettingsTests.swift` | Read/write each setting through UserDefaults |
| `RTMLearnerTests/StateManagerTests.swift` | isProcessed, markProcessed, lastRunDate round-trips |

---

## Task 1: Create the Xcode Project

**Files:** creates the entire project scaffold

- [ ] **Step 1: Create the project**

  In Xcode: File → New → Project → macOS → App
  - Product Name: `RTMLearner`
  - Bundle Identifier: `com.kuephi.rtm-learner`
  - Interface: SwiftUI
  - Language: Swift
  - Include Tests: ✓
  - Minimum Deployment: macOS 13.0

  Save inside `/Users/kuephi/projects/learn/chinese/` (the existing git repo root).

- [ ] **Step 2: Add Swift package dependencies**

  In Xcode: File → Add Package Dependencies

  Add **FeedKit**:
  ```
  https://github.com/nmdias/FeedKit.git
  ```
  Version: Up To Next Major from `9.0.0`
  Add to target: RTMLearner

  Add **SwiftSoup**:
  ```
  https://github.com/scinfu/SwiftSoup.git
  ```
  Version: Up To Next Major from `2.0.0`
  Add to target: RTMLearner

- [ ] **Step 3: Configure entitlements**

  In the RTMLearner target → Signing & Capabilities → + Capability:
  - Add **Keychain Sharing** (leave the default group, needed for Keychain API access)
  - Add **App Sandbox** → disable if present (personal tool, not App Store)

  Or open `RTMLearner.entitlements` and ensure:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>com.apple.security.app-sandbox</key>
      <false/>
  </dict>
  </plist>
  ```

- [ ] **Step 4: Create the folder structure**

  In Xcode's project navigator, create groups (New Group):
  ```
  RTMLearner/
    App/
    Menubar/
    Preferences/
    Pipeline/
    Providers/
    Models/
    Support/
  RTMLearnerTests/
  ```

- [ ] **Step 5: Verify the project builds**

  Press `Cmd+B`. Expected: Build Succeeded.

- [ ] **Step 6: Commit**

  ```bash
  cd /Users/kuephi/projects/learn/chinese
  git add RTMLearner/
  git commit -m "chore: scaffold Xcode project with FeedKit and SwiftSoup"
  ```

---

## Task 2: ScheduleConfig Model

**Files:**
- Create: `RTMLearner/RTMLearner/Models/ScheduleConfig.swift`
- Create: `RTMLearner/RTMLearnerTests/ModelTests.swift`

- [ ] **Step 1: Write the failing test**

  Create `RTMLearnerTests/ModelTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class ModelTests: XCTestCase {

      // MARK: - ScheduleConfig

      func test_scheduleConfig_encodesAndDecodes() throws {
          let config = ScheduleConfig(days: [.monday, .friday], hour: 8, minute: 30)
          let data = try JSONEncoder().encode(config)
          let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)
          XCTAssertEqual(decoded.days, [.monday, .friday])
          XCTAssertEqual(decoded.hour, 8)
          XCTAssertEqual(decoded.minute, 30)
      }

      func test_weekday_rawValues_matchCalendar() {
          // Calendar.current.component(.weekday) uses 1=Sun, 2=Mon … 7=Sat
          XCTAssertEqual(Weekday.sunday.rawValue, 1)
          XCTAssertEqual(Weekday.monday.rawValue, 2)
          XCTAssertEqual(Weekday.saturday.rawValue, 7)
      }

      func test_scheduleConfig_defaultConfig_isValid() {
          let config = ScheduleConfig.defaultConfig
          XCTAssertFalse(config.days.isEmpty)
          XCTAssertTrue((0...23).contains(config.hour))
          XCTAssertTrue((0...59).contains(config.minute))
      }
  }
  ```

- [ ] **Step 2: Run the test — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'ScheduleConfig'".

- [ ] **Step 3: Implement ScheduleConfig**

  Create `RTMLearner/Models/ScheduleConfig.swift`:

  ```swift
  import Foundation

  enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
      case sunday    = 1
      case monday    = 2
      case tuesday   = 3
      case wednesday = 4
      case thursday  = 5
      case friday    = 6
      case saturday  = 7

      var id: Int { rawValue }

      var shortName: String {
          switch self {
          case .sunday:    return "S"
          case .monday:    return "M"
          case .tuesday:   return "T"
          case .wednesday: return "W"
          case .thursday:  return "T"
          case .friday:    return "F"
          case .saturday:  return "S"
          }
      }

      var displayName: String {
          switch self {
          case .sunday:    return "Sun"
          case .monday:    return "Mon"
          case .tuesday:   return "Tue"
          case .wednesday: return "Wed"
          case .thursday:  return "Thu"
          case .friday:    return "Fri"
          case .saturday:  return "Sat"
          }
      }
  }

  struct ScheduleConfig: Codable, Equatable {
      var days: Set<Weekday>
      var hour: Int      // 0–23
      var minute: Int    // 0–59

      static let defaultConfig = ScheduleConfig(
          days: [.monday, .wednesday, .friday],
          hour: 8,
          minute: 0
      )
  }
  ```

- [ ] **Step 4: Run the test — expect PASS**

  `Cmd+U`. Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add ScheduleConfig and Weekday models"
  ```

---

## Task 3: Episode Model

**Files:**
- Create: `RTMLearner/RTMLearner/Models/Episode.swift`
- Modify: `RTMLearner/RTMLearnerTests/ModelTests.swift`

- [ ] **Step 1: Write the failing tests**

  Append to `ModelTests.swift`:

  ```swift
      // MARK: - Episode

      func test_word_encodesAndDecodes() throws {
          let word = Word(
              type: "priority", number: 1,
              chinese: "测试", pinyin: "cè shì",
              english: "test",
              exampleZh: "这是测试", exampleEn: "This is a test"
          )
          let data = try JSONEncoder().encode(word)
          let decoded = try JSONDecoder().decode(Word.self, from: data)
          XCTAssertEqual(decoded.chinese, "测试")
          XCTAssertEqual(decoded.german, "")
          XCTAssertEqual(decoded.exampleDe, "")
      }

      func test_episode_decodesFromPythonJSON() throws {
          // Matches the schema produced by the Python pipeline
          let json = """
          {
            "episode": 265,
            "title": "#265[中级]: Test",
            "url": "https://example.com",
            "pub_date": "2024-01-01",
            "text_simplified": "文章",
            "text_traditional": "文章",
            "words": [],
            "idioms": [],
            "dialogue": [],
            "grammar": [],
            "exercises": []
          }
          """.data(using: .utf8)!
          let episode = try JSONDecoder().decode(Episode.self, from: json)
          XCTAssertEqual(episode.episode, 265)
          XCTAssertEqual(episode.textSimplified, "文章")
      }

      func test_episode_encodesWithSnakeCaseKeys() throws {
          let episode = Episode(
              episode: 1, title: "Test", url: "https://x.com", pubDate: "2024-01-01",
              textSimplified: "简体", textTraditional: "繁體",
              words: [], idioms: [], dialogue: [], grammar: [], exercises: []
          )
          let data = try JSONEncoder().encode(episode)
          let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
          XCTAssertNotNil(dict["text_simplified"])
          XCTAssertNotNil(dict["pub_date"])
      }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'Episode'".

- [ ] **Step 3: Implement Episode**

  Create `RTMLearner/Models/Episode.swift`:

  ```swift
  import Foundation

  struct Episode: Codable {
      var episode: Int
      var title: String
      var url: String
      var pubDate: String
      var textSimplified: String
      var textTraditional: String
      var words: [Word]
      var idioms: [Word]
      var dialogue: [DialogueLine]
      var grammar: [GrammarPattern]
      var exercises: [Exercise]

      enum CodingKeys: String, CodingKey {
          case episode, title, url
          case pubDate        = "pub_date"
          case textSimplified = "text_simplified"
          case textTraditional = "text_traditional"
          case words, idioms, dialogue, grammar, exercises
      }
  }

  struct Word: Codable {
      var type: String
      var number: Int
      var chinese: String
      var pinyin: String
      var english: String
      var exampleZh: String
      var exampleEn: String
      var german: String
      var exampleDe: String

      enum CodingKeys: String, CodingKey {
          case type, number, chinese, pinyin, english
          case exampleZh = "example_zh"
          case exampleEn = "example_en"
          case german
          case exampleDe = "example_de"
      }

      init(type: String, number: Int, chinese: String, pinyin: String,
           english: String, exampleZh: String, exampleEn: String,
           german: String = "", exampleDe: String = "") {
          self.type = type; self.number = number; self.chinese = chinese
          self.pinyin = pinyin; self.english = english
          self.exampleZh = exampleZh; self.exampleEn = exampleEn
          self.german = german; self.exampleDe = exampleDe
      }
  }

  struct DialogueLine: Codable {
      var speaker: String
      var line: String
  }

  struct GrammarPattern: Codable {
      var pattern: String
      var pinyin: String
      var meaningEn: String
      var examplesZh: [String]

      enum CodingKeys: String, CodingKey {
          case pattern, pinyin
          case meaningEn   = "meaning_en"
          case examplesZh  = "examples_zh"
      }
  }

  struct Exercise: Codable {
      var question: String
      var options: [String]
      var answerIndex: Int
      var answerText: String

      enum CodingKeys: String, CodingKey {
          case question, options
          case answerIndex = "answer_index"
          case answerText  = "answer_text"
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all model tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add Episode, Word, and related Codable models"
  ```

---

## Task 4: LLMProviderType

**Files:**
- Create: `RTMLearner/RTMLearner/Models/LLMProviderType.swift`
- Modify: `RTMLearner/RTMLearnerTests/ModelTests.swift`

- [ ] **Step 1: Write the failing test**

  Append to `ModelTests.swift`:

  ```swift
      // MARK: - LLMProviderType

      func test_llmProviderType_defaultModels() {
          XCTAssertEqual(LLMProviderType.claude.defaultModel, "claude-sonnet-4-6")
          XCTAssertEqual(LLMProviderType.gemini.defaultModel, "gemini-2.0-flash")
          XCTAssertEqual(LLMProviderType.openai.defaultModel, "gpt-4o")
          XCTAssertNil(LLMProviderType.openrouter.defaultModel)
      }

      func test_llmProviderType_encodesAndDecodes() throws {
          let data = try JSONEncoder().encode(LLMProviderType.claude)
          let decoded = try JSONDecoder().decode(LLMProviderType.self, from: data)
          XCTAssertEqual(decoded, .claude)
      }
  ```

- [ ] **Step 2: Run the test — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'LLMProviderType'".

- [ ] **Step 3: Implement LLMProviderType**

  Create `RTMLearner/Models/LLMProviderType.swift`:

  ```swift
  import Foundation

  enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
      case claude
      case gemini
      case openai
      case openrouter

      var id: String { rawValue }

      var displayName: String {
          switch self {
          case .claude:      return "Claude"
          case .gemini:      return "Gemini"
          case .openai:      return "OpenAI"
          case .openrouter:  return "OpenRouter"
          }
      }

      /// Returns nil for OpenRouter — model is always required there.
      var defaultModel: String? {
          switch self {
          case .claude:      return "claude-sonnet-4-6"
          case .gemini:      return "gemini-2.0-flash"
          case .openai:      return "gpt-4o"
          case .openrouter:  return nil
          }
      }
  }
  ```

- [ ] **Step 4: Run the test — expect PASS**

  `Cmd+U`. Expected: all tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add LLMProviderType enum"
  ```

---

## Task 5: JSONRepair

**Files:**
- Create: `RTMLearner/RTMLearner/Support/JSONRepair.swift`
- Create: `RTMLearner/RTMLearnerTests/JSONRepairTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/JSONRepairTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class JSONRepairTests: XCTestCase {

      func test_clean_stripsJsonCodeFence() {
          let input = "```json\n{\"key\": \"value\"}\n```"
          XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
      }

      func test_clean_stripsPlainCodeFence() {
          let input = "```\n{\"key\": \"value\"}\n```"
          XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
      }

      func test_clean_leavesCleanJSONUnchanged() {
          let input = "{\"key\": \"value\"}"
          XCTAssertEqual(JSONRepair.clean(input), input)
      }

      func test_clean_tripsLeadingTrailingWhitespace() {
          let input = "  {\"key\": \"value\"}  "
          XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
      }

      func test_repair_parsesValidJSON() {
          let input = "{\"episode\": 1}"
          XCTAssertNotNil(JSONRepair.repair(input))
      }

      func test_repair_fixesTruncatedObject() {
          // Missing closing brace
          let input = "{\"episode\": 1, \"words\": ["
          let data = JSONRepair.repair(input)
          XCTAssertNotNil(data)
          // Should produce parseable JSON
          XCTAssertNotNil(try? JSONSerialization.jsonObject(with: data!))
      }

      func test_repair_stripsFenceBeforeRepairing() {
          let input = "```json\n{\"episode\": 1}\n```"
          XCTAssertNotNil(JSONRepair.repair(input))
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'JSONRepair'".

- [ ] **Step 3: Implement JSONRepair**

  Create `RTMLearner/Support/JSONRepair.swift`:

  ```swift
  import Foundation

  enum JSONRepair {

      /// Strip markdown code fences and trim whitespace.
      static func clean(_ raw: String) -> String {
          var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
          if s.hasPrefix("```") {
              s = s.replacingOccurrences(
                  of: #"^```(?:json)?\s*"#, with: "",
                  options: .regularExpression
              )
              s = s.replacingOccurrences(
                  of: #"\s*```$"#, with: "",
                  options: .regularExpression
              )
              s = s.trimmingCharacters(in: .whitespacesAndNewlines)
          }
          return s
      }

      /// Try to parse cleaned JSON; if it fails, attempt simple truncation repair.
      /// Returns nil only if repair is impossible.
      static func repair(_ raw: String) -> Data? {
          let cleaned = clean(raw)

          if let data = cleaned.data(using: .utf8),
             (try? JSONSerialization.jsonObject(with: data)) != nil {
              return data
          }

          // Attempt truncation repair
          var repaired = cleaned

          // Balance open string quotes
          let quoteCount = repaired.filter { $0 == "\"" }.count
          if quoteCount % 2 != 0 { repaired += "\"" }

          // Remove trailing comma before we close structures
          repaired = repaired.replacingOccurrences(
              of: #",\s*$"#, with: "", options: .regularExpression
          )

          // Count unmatched open brackets/braces
          var opens: [Character] = []
          var inString = false
          var prev: Character = "\0"
          for ch in repaired {
              if ch == "\"" && prev != "\\" { inString.toggle() }
              if !inString {
                  switch ch {
                  case "{": opens.append("}")
                  case "[": opens.append("]")
                  case "}", "]": _ = opens.popLast()
                  default: break
                  }
              }
              prev = ch
          }
          repaired += String(opens.reversed())

          return repaired.data(using: .utf8)
              .flatMap { data in
                  (try? JSONSerialization.jsonObject(with: data)) != nil ? data : nil
              }
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all 7 JSONRepair tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add JSONRepair — fence stripping and truncation repair"
  ```

---

## Task 6: KeychainHelper

**Files:**
- Create: `RTMLearner/RTMLearner/Support/KeychainHelper.swift`
- Create: `RTMLearner/RTMLearnerTests/KeychainHelperTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/KeychainHelperTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class KeychainHelperTests: XCTestCase {

      private let testKey = "com.rtm-learner.test.\(UUID().uuidString)"

      override func tearDown() {
          try? KeychainHelper.delete(for: testKey)
          super.tearDown()
      }

      func test_saveAndLoad_roundTrips() throws {
          try KeychainHelper.save("secret-value", for: testKey)
          let loaded = try KeychainHelper.load(for: testKey)
          XCTAssertEqual(loaded, "secret-value")
      }

      func test_load_throwsNotFoundWhenMissing() {
          XCTAssertThrowsError(try KeychainHelper.load(for: testKey)) { error in
              XCTAssertEqual(error as? KeychainError, .notFound)
          }
      }

      func test_save_overwritesExistingValue() throws {
          try KeychainHelper.save("first", for: testKey)
          try KeychainHelper.save("second", for: testKey)
          let loaded = try KeychainHelper.load(for: testKey)
          XCTAssertEqual(loaded, "second")
      }

      func test_delete_removesValue() throws {
          try KeychainHelper.save("value", for: testKey)
          try KeychainHelper.delete(for: testKey)
          XCTAssertThrowsError(try KeychainHelper.load(for: testKey))
      }

      func test_delete_succeedsWhenKeyMissing() {
          XCTAssertNoThrow(try KeychainHelper.delete(for: testKey))
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'KeychainHelper'".

- [ ] **Step 3: Implement KeychainHelper**

  Create `RTMLearner/Support/KeychainHelper.swift`:

  ```swift
  import Security
  import Foundation

  enum KeychainError: Error, Equatable {
      case notFound
      case unexpectedData
      case unhandledError(status: OSStatus)
  }

  enum KeychainHelper {
      private static let service = "com.kuephi.rtm-learner"

      static func save(_ value: String, for key: String) throws {
          let data = Data(value.utf8)
          // Delete any existing item first so overwrite always works
          let deleteQuery: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: key
          ]
          SecItemDelete(deleteQuery as CFDictionary)

          let addQuery: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: key,
              kSecValueData as String:   data
          ]
          let status = SecItemAdd(addQuery as CFDictionary, nil)
          guard status == errSecSuccess else {
              throw KeychainError.unhandledError(status: status)
          }
      }

      static func load(for key: String) throws -> String {
          let query: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: key,
              kSecReturnData as String:  true,
              kSecMatchLimit as String:  kSecMatchLimitOne
          ]
          var result: AnyObject?
          let status = SecItemCopyMatching(query as CFDictionary, &result)
          if status == errSecItemNotFound { throw KeychainError.notFound }
          guard status == errSecSuccess else {
              throw KeychainError.unhandledError(status: status)
          }
          guard let data = result as? Data,
                let string = String(data: data, encoding: .utf8) else {
              throw KeychainError.unexpectedData
          }
          return string
      }

      static func delete(for key: String) throws {
          let query: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: key
          ]
          let status = SecItemDelete(query as CFDictionary)
          guard status == errSecSuccess || status == errSecItemNotFound else {
              throw KeychainError.unhandledError(status: status)
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all 5 KeychainHelper tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add KeychainHelper for secure credential storage"
  ```

---

## Task 7: Settings

**Files:**
- Create: `RTMLearner/RTMLearner/Support/Settings.swift`
- Create: `RTMLearner/RTMLearnerTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/SettingsTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class SettingsTests: XCTestCase {

      var settings: Settings!
      let suiteName = "com.rtm-learner.test.\(UUID().uuidString)"

      override func setUp() {
          super.setUp()
          settings = Settings(suiteName: suiteName)
      }

      override func tearDown() {
          UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
          super.tearDown()
      }

      func test_defaultSchedule_matchesSpec() {
          XCTAssertEqual(settings.schedule, ScheduleConfig.defaultConfig)
      }

      func test_schedule_roundTrips() {
          let config = ScheduleConfig(days: [.tuesday, .thursday], hour: 9, minute: 15)
          settings.schedule = config
          XCTAssertEqual(settings.schedule, config)
      }

      func test_defaultProvider_isClaude() {
          XCTAssertEqual(settings.providerType, .claude)
      }

      func test_providerType_roundTrips() {
          settings.providerType = .openrouter
          XCTAssertEqual(settings.providerType, .openrouter)
      }

      func test_claudeModel_defaultsToEmpty() {
          XCTAssertEqual(settings.claudeModel, "")
      }

      func test_openRouterModel_roundTrips() {
          settings.openRouterModel = "anthropic/claude-3.5-sonnet"
          XCTAssertEqual(settings.openRouterModel, "anthropic/claude-3.5-sonnet")
      }

      func test_activeModel_returnsDefaultWhenOverrideEmpty() {
          settings.providerType = .claude
          settings.claudeModel = ""
          XCTAssertEqual(settings.activeModel(), "claude-sonnet-4-6")
      }

      func test_activeModel_returnsOverrideWhenSet() {
          settings.providerType = .claude
          settings.claudeModel = "claude-haiku-4-5-20251001"
          XCTAssertEqual(settings.activeModel(), "claude-haiku-4-5-20251001")
      }

      func test_activeModel_openRouterReturnsSelectedModel() {
          settings.providerType = .openrouter
          settings.openRouterModel = "openai/gpt-4o"
          XCTAssertEqual(settings.activeModel(), "openai/gpt-4o")
      }

      func test_lastRunDate_roundTrips() {
          let date = Date(timeIntervalSince1970: 1_700_000_000)
          settings.lastRunDate = date
          XCTAssertEqual(settings.lastRunDate?.timeIntervalSince1970,
                         date.timeIntervalSince1970, accuracy: 1)
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'Settings'".

- [ ] **Step 3: Implement Settings**

  Create `RTMLearner/Support/Settings.swift`:

  ```swift
  import Foundation
  import Observation

  @Observable
  final class Settings {
      private let defaults: UserDefaults

      init(suiteName: String? = nil) {
          if let name = suiteName {
              defaults = UserDefaults(suiteName: name)!
          } else {
              defaults = .standard
          }
      }

      var schedule: ScheduleConfig {
          get {
              guard let data = defaults.data(forKey: "schedule"),
                    let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data)
              else { return .defaultConfig }
              return config
          }
          set {
              let data = try? JSONEncoder().encode(newValue)
              defaults.set(data, forKey: "schedule")
          }
      }

      var providerType: LLMProviderType {
          get {
              let raw = defaults.string(forKey: "providerType") ?? LLMProviderType.claude.rawValue
              return LLMProviderType(rawValue: raw) ?? .claude
          }
          set { defaults.set(newValue.rawValue, forKey: "providerType") }
      }

      var claudeModel: String {
          get { defaults.string(forKey: "claudeModel") ?? "" }
          set { defaults.set(newValue, forKey: "claudeModel") }
      }

      var geminiModel: String {
          get { defaults.string(forKey: "geminiModel") ?? "" }
          set { defaults.set(newValue, forKey: "geminiModel") }
      }

      var openAIModel: String {
          get { defaults.string(forKey: "openAIModel") ?? "" }
          set { defaults.set(newValue, forKey: "openAIModel") }
      }

      var openRouterModel: String {
          get { defaults.string(forKey: "openRouterModel") ?? "" }
          set { defaults.set(newValue, forKey: "openRouterModel") }
      }

      var lastRunDate: Date? {
          get {
              let t = defaults.double(forKey: "lastRunDate")
              return t > 0 ? Date(timeIntervalSince1970: t) : nil
          }
          set {
              defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "lastRunDate")
          }
      }

      /// Returns the model to use for the current provider, falling back to the provider default.
      func activeModel() -> String {
          switch providerType {
          case .claude:
              let m = claudeModel.trimmingCharacters(in: .whitespaces)
              return m.isEmpty ? "claude-sonnet-4-6" : m
          case .gemini:
              let m = geminiModel.trimmingCharacters(in: .whitespaces)
              return m.isEmpty ? "gemini-2.0-flash" : m
          case .openai:
              let m = openAIModel.trimmingCharacters(in: .whitespaces)
              return m.isEmpty ? "gpt-4o" : m
          case .openrouter:
              return openRouterModel
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all 10 Settings tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add Settings — UserDefaults wrapper with active model resolution"
  ```

---

## Task 8: StateManager

**Files:**
- Create: `RTMLearner/RTMLearner/Support/StateManager.swift`
- Create: `RTMLearner/RTMLearnerTests/StateManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/StateManagerTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class StateManagerTests: XCTestCase {

      var manager: StateManager!
      var tempDir: URL!

      override func setUp() async throws {
          try await super.setUp()
          tempDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
          manager = await StateManager(directory: tempDir)
      }

      override func tearDown() async throws {
          try? FileManager.default.removeItem(at: tempDir)
          try await super.tearDown()
      }

      func test_newManager_hasNoProcessedURLs() async {
          let processed = await manager.isProcessed(url: "https://example.com")
          XCTAssertFalse(processed)
      }

      func test_markProcessed_makesURLProcessed() async throws {
          try await manager.markProcessed(url: "https://example.com/1")
          let processed = await manager.isProcessed(url: "https://example.com/1")
          XCTAssertTrue(processed)
      }

      func test_markProcessed_doesNotAffectOtherURLs() async throws {
          try await manager.markProcessed(url: "https://example.com/1")
          let other = await manager.isProcessed(url: "https://example.com/2")
          XCTAssertFalse(other)
      }

      func test_state_persistsAcrossInstances() async throws {
          try await manager.markProcessed(url: "https://example.com/1")
          let manager2 = await StateManager(directory: tempDir)
          let processed = await manager2.isProcessed(url: "https://example.com/1")
          XCTAssertTrue(processed)
      }

      func test_lastRunDate_isNilInitially() async {
          let date = await manager.lastRunDate
          XCTAssertNil(date)
      }

      func test_setLastRunDate_persistsAcrossInstances() async throws {
          let date = Date(timeIntervalSince1970: 1_700_000_000)
          try await manager.setLastRunDate(date)
          let manager2 = await StateManager(directory: tempDir)
          let loaded = await manager2.lastRunDate
          XCTAssertEqual(loaded?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'StateManager'".

- [ ] **Step 3: Implement StateManager**

  Create `RTMLearner/Support/StateManager.swift`:

  ```swift
  import Foundation

  actor StateManager {
      static let shared: StateManager = {
          let appSupport = FileManager.default.urls(
              for: .applicationSupportDirectory, in: .userDomainMask
          )[0].appendingPathComponent("RTMLearner")
          try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
          return StateManager(directory: appSupport)
      }()

      private var state: PersistedState
      private let fileURL: URL

      private struct PersistedState: Codable {
          var processedURLs: [String] = []
          var lastRunDate: Date?

          enum CodingKeys: String, CodingKey {
              case processedURLs = "processed_urls"
              case lastRunDate   = "last_run_date"
          }
      }

      init(directory: URL) {
          fileURL = directory.appendingPathComponent("state.json")
          if let data = try? Data(contentsOf: fileURL),
             let loaded = try? JSONDecoder().decode(PersistedState.self, from: data) {
              state = loaded
          } else {
              state = PersistedState()
          }
      }

      func isProcessed(url: String) -> Bool {
          state.processedURLs.contains(url)
      }

      func markProcessed(url: String) throws {
          state.processedURLs.append(url)
          try persist()
      }

      var lastRunDate: Date? { state.lastRunDate }

      func setLastRunDate(_ date: Date) throws {
          state.lastRunDate = date
          try persist()
      }

      private func persist() throws {
          let data = try JSONEncoder().encode(state)
          try data.write(to: fileURL, options: .atomic)
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all 6 StateManager tests PASS.

- [ ] **Step 5: Migrate existing state.json on first launch** *(add a migration helper used in Plan 3)*

  Append to `StateManager.swift`:

  ```swift
  extension StateManager {
      /// Call once at app launch. Copies data/state.json from the old Python project
      /// into Application Support if it exists and the new state file doesn't yet.
      static func migrateFromPythonProjectIfNeeded(pythonDataDir: URL) async {
          let source = pythonDataDir.appendingPathComponent("state.json")
          guard FileManager.default.fileExists(atPath: source.path) else { return }
          let dest = shared.fileURL
          guard !FileManager.default.fileExists(atPath: dest.path) else { return }
          try? FileManager.default.copyItem(at: source, to: dest)
      }
  }
  ```

- [ ] **Step 6: Run all tests — expect PASS**

  `Cmd+U`. Expected: all tests in the suite PASS.

- [ ] **Step 7: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add StateManager — persist processed URLs and last run date"
  ```

---

## Plan 1 Complete

All foundation types are in place and tested. Continue with **Plan 2: LLM Providers & Pipeline**.

Run the full test suite one final time before moving on:
```
Cmd+U — expect: all tests PASS, 0 failures
```
