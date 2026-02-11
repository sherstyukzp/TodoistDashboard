import Foundation

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    var isTomorrow: Bool { Calendar.current.isDateInTomorrow(self) }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }

    var startOfMonth: Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: components) ?? self
    }

    var weekdayIndex: Int {
        // Monday = 0, Sunday = 6
        let wd = Calendar.current.component(.weekday, from: self)
        return (wd + 5) % 7
    }

    var hourOfDay: Int {
        Calendar.current.component(.hour, from: self)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }

    var dayOfWeekShort: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: self)
    }

    static func dates(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var current = start.startOfDay
        let endDay = end.startOfDay
        while current <= endDay {
            dates.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? endDay
        }
        return dates
    }
}
