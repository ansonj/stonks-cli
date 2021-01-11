import FMDB

struct DatabaseUtilities {
    // MARK: Dates
    
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()
    
    static func date(fromString string: String) -> Date {
        guard let date = dateFormatter.date(from: string) else {
            Prompt.exitStonks(withMessage: "Couldn't convert '\(string)' to a date")
        }
        return date
    }
    
    static func string(fromDate date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    static func subsequentYearMonth(forYearMonth yearMonth: String) -> String {
        let errorString = "ERROR"
        let separator: Character = "-"
        
        let components = yearMonth.split(separator: separator)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1])
        else { return errorString }
        
        let newMonth = month >= 12 ? 1 : month + 1
        let newYear = newMonth == 1 ? year + 1 : year
        
        let newYearMonth = newYear.description + separator.description + (newMonth < 10 ? "0" : "") + newMonth.description
        return newYearMonth
    }
    
    // MARK: Exiting
    
    static func exitWithError(fromDatabase db: FMDatabase, duringActivity activity: String) -> Never {
        let code = db.lastErrorCode()
        let message = db.lastErrorMessage()
        exitWithErrorMessage("\(code) \(message)", duringActivity: activity)
    }
    
    static func exitWithError(_ error: Error, duringActivity activity: String) -> Never {
        exitWithErrorMessage(error.localizedDescription, duringActivity: activity)
    }
    
    static func exitWithErrorMessage(_ message: String, duringActivity activity: String) -> Never {
        Prompt.exitStonks(withMessage: "Database error while \(activity): \(message)")
    }
}
