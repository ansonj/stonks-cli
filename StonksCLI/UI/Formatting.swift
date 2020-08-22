import Foundation

struct Formatting {
    private static let currencyFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        return fmt
    }()
    static func string(forCurrency c: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: c)) ?? "$?.??"
    }
    
    private static let percentageFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .percent
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt
    }()
    static func string(forPercentage p: Double) -> String {
        return percentageFormatter.string(from: NSNumber(value: p)) ?? "?.??%"
    }
    
    private static let doubleFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 6
        fmt.maximumFractionDigits = 6
        return fmt
    }()
    static func string(forDouble d: Double) -> String {
        return doubleFormatter.string(from: NSNumber(value: d)) ?? "?.??????"
    }
    
    private static let friendlyDateFormatter = { () -> DateFormatter in
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM dd, yyyy"
        return fmt
    }()
    static func friendlyDateString(forDatabaseDateString dbDateString: String) -> String {
        let actualDate = DatabaseUtilities.date(fromString: dbDateString)
        return friendlyDateFormatter.string(from: actualDate)
    }
}
