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
        // FIXME: Implement
        return "2020-12"
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
