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
