# RTM Learner — macOS App Design Spec
**Date:** 2026-04-04
**Status:** Approved

---

## Overview

RTM Learner is a native Swift/SwiftUI macOS menubar app that automatically fetches, parses, translates, and exports RTM Mandarin intermediate (`中级`) podcast lessons as Pleco flashcards.

It is a single self-contained app — no Python runtime, no external scripts. The entire pipeline is implemented in Swift. It is distributed via a personal Homebrew cask and runs permanently in the background as a macOS Login Item.

---

## App Behaviour

- **Menubar-only** — `LSUIElement = true`, no Dock icon
- **Always running** — registered as a Login Item via `SMAppService`
- **Menubar icon** — clicking opens a popover with status and quick actions
- **Preferences** — a separate window, opened from the popover or `Cmd+,`

---

## Menubar Popover

Contents:
- App name + icon
- Last run: date/time and success/failure status
- Next scheduled run: weekday + time
- Current schedule summary (e.g. "Mon · Wed · Fri at 08:00")
- **Run now** button
- **Show log** — scrolls to the Log tab in Preferences
- **Preferences…** — opens the Preferences window
- Separator
- **Quit**

---

## Preferences Window

A `NavigationSplitView` window (sidebar + detail panel). Four sections:

### 1. Schedule

- **Days** — seven circles labelled M T W T F S S; tap to toggle each on/off. At least one day must be selected.
- **Time** — a time picker (hour + minute)
- **Launch at login** — toggle backed by `SMAppService`

### 2. Provider

A segmented control: `Claude | Gemini | OpenAI | OpenRouter`

**Claude, Gemini, OpenAI:**
- API key field (stored in Keychain, masked)
- Optional model override field (free text; blank = use provider default)

**OpenRouter:**
- API key field (stored in Keychain, masked)
- Model selector — a searchable dropdown populated from `GET https://openrouter.ai/api/v1/models`, grouped by provider family (Anthropic, OpenAI, Google, Meta, …)
- A **Refresh models** button re-fetches the list
- If the fetch fails (no internet, invalid key), falls back to a free-text field with a warning
- The selected model ID is stored in UserDefaults

Provider defaults (used when model override is blank):

| Provider | Default model |
|----------|--------------|
| Claude | `claude-sonnet-4-6` |
| Gemini | `gemini-2.0-flash` |
| OpenAI | `gpt-4o` |
| OpenRouter | (required — no default) |

### 3. Auth

- Substack email field
- Substack password field (Keychain, masked)
- Session status: "Active · expires in N days" or "Expired"
- **Refresh session** button — attempts re-authentication via the Substack API and updates the session cookie in Keychain
- **Known limitation:** Substack blocks automated logins via their API. If the refresh fails, the UI shows an error and instructions to manually paste the `substack.sid` cookie from browser DevTools. The cookie field accepts a manual paste for this fallback.

### 4. Log

- Scrollable, monospaced text view of the last pipeline run output
- Timestamp header per run
- Auto-scrolls to bottom on new output
- **Clear log** button

---

## Pipeline

`PipelineRunner` orchestrates four sequential async steps. Each step is a separate Swift type. The active `LLMProvider` is injected at run time from the current settings.

### Step 1 — Fetcher

- Parse the RTM RSS feed using **FeedKit**
- Filter entries where title contains `中级`
- Skip URLs already in `StateManager`
- Download each Substack page via `URLSession` with the cached session cookie
- On HTTP 401/403: attempt re-authentication once, then fail with an error
- Strip HTML to plain text using **SwiftSoup** (remove `script`, `style`, `nav`, `footer`, `header`, `.subscribe-widget`; prefer `div.available-content` → `div.post-content` → `article` → `main`)

### Step 2 — Parser

- Build the extraction prompt (same schema as the current Python implementation)
- Call the configured `LLMProvider`
- Run the response through `JSONRepair` (strip markdown fences, fix truncated JSON)
- Decode into `Episode` via `Codable`
- Merge feed metadata (episode number, title, URL, pub date) into the struct

### Step 3 — Translator

- Build the translation prompt with all words + idioms and the episode topic
- Call the configured `LLMProvider`
- Decode the response and attach `german` and `example_de` fields to each word and idiom

### Step 4 — PlecoExporter

- Format each word/idiom as `chinese\tpinyin\tdefinition` (Pleco import format)
- Write to `~/Library/Application Support/RTMLearner/pleco/<episode>_pleco.txt`
- Copy to `~/Library/Mobile Documents/com~apple~CloudDocs/RTM/` (iCloud Drive sync to iPhone)
- Failure to copy to iCloud is logged but does not fail the pipeline

After a successful run, `StateManager` records the episode URL and the run timestamp.

---

## LLM Provider Architecture

```
LLMProvider (protocol)
└── complete(prompt: String) async throws -> String

ChatCompletionProvider (shared struct — OpenAI-compatible REST)
├── OpenAIProvider      api.openai.com
└── OpenRouterProvider  openrouter.ai  (model ID required)

ClaudeProvider          Anthropic Messages API
GeminiProvider          Google Generative Language API
```

`ChatCompletionProvider` handles the request/response format shared by OpenAI and OpenRouter. New providers require one new file conforming to `LLMProvider` and one new case in `ProviderView`. No changes to the pipeline.

---

## Scheduler

`ScheduleManager` is responsible for computing when the next run should fire and ensuring no run is missed.

### Normal operation

On launch and after every completed run:
1. Call `computeNextRunDate(schedule:, from: now)`:
   - If today is a scheduled weekday and the scheduled time is still in the future → return today at HH:mm
   - Otherwise → find the next calendar date that is a scheduled weekday, return that date at HH:mm
2. Schedule a single `Timer` with `fireAt: nextRunDate`
3. When the timer fires → run the pipeline → reschedule

The timer fires **exactly once per scheduled run**. No polling.

### Missed-run detection (on launch)

On every app launch, before scheduling the next timer:
1. Read `lastRunDate` from UserDefaults
2. Call `mostRecentScheduledOccurrence(before: now)` — the last scheduled time that has already passed
3. If `lastRunDate < mostRecentScheduledOccurrence` → a run was missed; fire immediately
4. Then schedule the next regular timer

If the Mac was shut down across multiple scheduled times, only the most recent missed run fires (once). Running the pipeline multiple times in a row has no benefit — the RSS feed state is checked fresh each time.

### Schedule changes

When the user saves a new schedule in Preferences:
1. Invalidate the pending timer
2. Re-run missed-run detection
3. Recompute and schedule the next run

---

## Storage

| Data | Location |
|------|----------|
| API keys, Substack password, session cookie | macOS Keychain |
| Schedule config, active provider, model, last run date | UserDefaults |
| Processed episode URLs | `~/Library/Application Support/RTMLearner/state.json` |
| Episode JSON | `~/Library/Application Support/RTMLearner/episodes/<n>.json` |
| Pleco flashcard files | `~/Library/Application Support/RTMLearner/pleco/<n>_pleco.txt` |
| iCloud copy | `~/Library/Mobile Documents/com~apple~CloudDocs/RTM/` |

The episode JSON schema is identical to the current Python output — existing saved files remain valid.

---

## Project Structure

```
RTMLearner/
  RTMLearner.xcodeproj
  RTMLearner/
    App/
      RTMLearnerApp.swift           entry point, LSUIElement = true
      AppDelegate.swift             NSStatusBar item setup
    Menubar/
      MenubarController.swift       icon + popover lifecycle
      MenubarPopoverView.swift      SwiftUI popover content
    Preferences/
      PreferencesWindowController.swift
      PreferencesView.swift         NavigationSplitView shell
      ScheduleView.swift
      ProviderView.swift
      AuthView.swift
      LogView.swift
    Pipeline/
      PipelineRunner.swift          orchestrates the 4 steps
      Fetcher.swift
      Parser.swift
      Translator.swift
      PlecoExporter.swift
    Providers/
      LLMProvider.swift             protocol definition
      ChatCompletionProvider.swift  shared OpenAI-format REST logic
      ClaudeProvider.swift
      GeminiProvider.swift
      OpenAIProvider.swift
      OpenRouterProvider.swift
    Models/
      Episode.swift                 Codable structs: Word, Idiom, Dialogue, Grammar, Exercise
      ScheduleConfig.swift          days: Set<Weekday>, hour: Int, minute: Int
    Support/
      Settings.swift                UserDefaults wrapper
      KeychainHelper.swift          read/write secrets
      StateManager.swift            processed URLs + last run timestamp
      ScheduleManager.swift         nextRunDate computation + Timer management
      JSONRepair.swift              strip fences, fix truncated JSON
    RTMLearnerTests/
      PlecoExporterTests.swift
      ScheduleManagerTests.swift    nextRunDate, missed-run detection
      JSONRepairTests.swift
      MockLLMProvider.swift
      ParserTests.swift
      TranslatorTests.swift
```

---

## Distribution

1. Build and code-sign the `.app` in Xcode (requires Apple Developer account for Gatekeeper)
2. Zip and upload to a GitHub Release in the source repo
3. Personal Homebrew tap: `kuephi/homebrew-tools` (separate small GitHub repo)
4. Cask formula in the tap points to the release zip URL + SHA256

**Install:**
```bash
brew tap kuephi/tools
brew install --cask rtm-learner
```

---

## Migration from Python project

- The Python source files (`main.py`, `fetcher.py`, `parser.py`, `translator.py`, `auth.py`, `exporters/`) are retired and removed
- `launchd/` and `run.sh` are removed (scheduling moves into the app)
- `data/episodes/` content remains valid — same JSON schema
- `data/state.json` is migrated to Application Support on first launch
- `requirements.txt`, `pytest.ini`, `tests/` are removed
- `CLAUDE.md` is updated to reflect the Swift project

---

## Out of Scope

- Push notifications on run completion
- Multiple feed sources
- Reading the episode JSON back in-app (flashcard review UI)
- Windows / Linux support
