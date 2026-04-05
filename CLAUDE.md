# CLAUDE.md

## Project

RTM Learner is a native Swift/SwiftUI macOS menubar app. It fetches RTM Mandarin
intermediate (中级) lessons, parses them with an LLM, translates vocabulary to German,
and exports Pleco flashcard files to iCloud Drive.

## Xcode project

Open `RTM Learner/RTM Learner.xcodeproj` in Xcode.

- Minimum deployment: macOS 13.0
- Swift packages: FeedKit, SwiftSoup (resolved automatically)
- Run tests: Cmd+U
- Run app: Cmd+R

## Architecture

See `docs/superpowers/specs/2026-04-04-rtm-learner-macos-app-design.md`

## Distribution

See Plan 3 Task 10 in `docs/superpowers/plans/`.
