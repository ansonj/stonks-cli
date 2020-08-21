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
}
