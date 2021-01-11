import Foundation

struct Formatting {
    // MARK: - Currency
    
    private static let currencyFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        return fmt
    }()
    static func string(forCurrency c: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: c)) ?? "$?.??"
    }
    
    // MARK: - Percentage
    
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
    
    // MARK: - Doubles
    
    private static let normalDoubleLength = 6
    private static let normalDoubleFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = normalDoubleLength
        fmt.maximumFractionDigits = normalDoubleLength
        return fmt
    }()
    static func string(forNormalDouble d: Double) -> String {
        return normalDoubleFormatter.string(from: NSNumber(value: d)) ?? "?.\(String(repeating: "?", count: normalDoubleLength))"
    }
    private static let longDoubleLength = 8
    private static let longDoubleFormatter = { () -> NumberFormatter in
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = longDoubleLength
        fmt.maximumFractionDigits = longDoubleLength
        return fmt
    }()
    static func string(forLongDouble d: Double) -> String {
        return longDoubleFormatter.string(from: NSNumber(value: d)) ?? "?.\(String(repeating: "?", count: longDoubleLength))"
    }
    
    // MARK: - Dates
    
    private static let friendlyDateFormatter = { () -> DateFormatter in
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM dd, yyyy"
        return fmt
    }()
    static func friendlyDateString(forDatabaseDateString dbDateString: String) -> String {
        let actualDate = DatabaseUtilities.date(fromString: dbDateString)
        return friendlyDateFormatter.string(from: actualDate)
    }
    static func friendlyDateString(forDate date: Date) -> String {
        return friendlyDateFormatter.string(from: date)
    }
    
    private static let shortDateFormatter = { () -> DateFormatter in
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd/yyyy"
        return fmt
    }()
    static func shortDateString(forDate date: Date) -> String {
        return shortDateFormatter.string(from: date)
    }
}
