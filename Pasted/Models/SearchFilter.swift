import Foundation

/// Defines date range presets and custom ranges for filtering clipboard history.
enum DateRange: Hashable, Identifiable {
    case today
    case yesterday
    case lastSevenDays
    case lastThirtyDays
    case custom(start: Date, end: Date)

    var id: String {
        switch self {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .lastSevenDays: return "last7"
        case .lastThirtyDays: return "last30"
        case .custom(let start, let end):
            return "custom:\(start.timeIntervalSince1970):\(end.timeIntervalSince1970)"
        }
    }

    /// Returns the start date for this range relative to now.
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .yesterday:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        case .lastSevenDays:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: now) ?? now)
        case .lastThirtyDays:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        case .custom(let start, _):
            return start
        }
    }

    /// Returns the end date for this range.
    /// For `.yesterday`, the end is midnight today.
    /// For `.custom`, the end is the provided end date.
    /// For other presets, returns `Date()` (now).
    var endDate: Date {
        switch self {
        case .yesterday:
            return Calendar.current.startOfDay(for: Date())
        case .custom(_, let end):
            return end
        case .today, .lastSevenDays, .lastThirtyDays:
            return Date()
        }
    }

    /// Human-readable label for the date range.
    var displayLabel: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .lastSevenDays: return "Last 7 Days"
        case .lastThirtyDays: return "Last 30 Days"
        case .custom:
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
        }
    }
}

/// Represents a single search filter applied to clipboard history queries.
/// Filters combine with AND logic when multiple are active.
enum SearchFilter: Hashable, Identifiable {
    case contentType(ContentType)
    case sourceApp(bundleID: String, name: String)
    case dateRange(DateRange)

    var id: String {
        switch self {
        case .contentType(let type):
            return "type:\(type.rawValue)"
        case .sourceApp(let bundleID, _):
            return "app:\(bundleID)"
        case .dateRange(let range):
            return "date:\(range.id)"
        }
    }

    /// Human-readable label for the filter.
    var displayLabel: String {
        switch self {
        case .contentType(let type):
            return type.rawValue.capitalized
        case .sourceApp(_, let name):
            return name
        case .dateRange(let range):
            return range.displayLabel
        }
    }

    /// SF Symbol icon name for the filter.
    var iconName: String {
        switch self {
        case .contentType(let type):
            switch type {
            case .text:     return "doc.text"
            case .richText: return "doc.richtext"
            case .image:    return "photo"
            case .url:      return "link"
            case .file:     return "doc"
            }
        case .sourceApp:
            return "app.badge"
        case .dateRange:
            return "calendar"
        }
    }
}
