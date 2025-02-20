import Foundation

struct Utilities {
    static let errorString = "\(Logger.stonksGlyph)ERROR"
    
    static func daysBetween(_ start: Date, and end: Date) -> Int {
        // https://stackoverflow.com/questions/24723431/#comment58538259_28163560
        let cal = Calendar.current
        guard let noonStart = cal.date(bySettingHour: 12, minute: 0, second: 0, of: start) else {
            Prompt.exitStonks(withMessage: "Couldn't set start date to noon: \(start)")
        }
        guard let noonEnd = cal.date(bySettingHour: 12, minute: 0, second: 0, of: end) else {
            Prompt.exitStonks(withMessage: "Couldn't set end date to noon: \(end)")
        }
        return cal.dateComponents([.day], from: noonStart, to: noonEnd).day ?? -1
    }
}

extension Double {
    var isBasicallyZero: Bool {
        abs(self) < 0.01
    }
    
    var roundedToNearestCent: Double {
        (self * 100).rounded() / 100
    }
}

enum Emoji: String {
    case greenCheckmark = "\u{2705}"
    case redX = "\u{274C}"
}

extension Bool {
    var emoji: String {
        return self ? Emoji.greenCheckmark.rawValue : Emoji.redX.rawValue
    }
}
