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
