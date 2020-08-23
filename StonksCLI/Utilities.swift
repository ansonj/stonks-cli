import Foundation

struct Utilities {
    static func daysBetween(_ start: Date, and end: Date) -> Int {
        // FIXME: There is a bug here; need to ensure these dates have the same time
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? -1
    }
}
