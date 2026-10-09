import Foundation

/// Square of the day, the same for everyone on a given calendar day.
enum Daily {
    static func number(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let key = (c.year ?? 0) * 372 + (c.month ?? 0) * 31 + (c.day ?? 0)
        return 10 + (key * 37) % 90
    }
}
