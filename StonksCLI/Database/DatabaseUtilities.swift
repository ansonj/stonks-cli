import FMDB

struct DatabaseUtilities {
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
