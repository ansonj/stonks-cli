import FMDB

struct DatabaseFileManager {
    static func verifyDatabase(atPath path: String) {
        createDatabaseIfNeeded(atPath: path)
    }
    
    private static func createDatabaseIfNeeded(atPath path: String) {
        if FileManager.default.isReadableFile(atPath: path) {
           return
        }
        let db = FMDatabase(path: path)
        guard db.open() else {
            exitWithError(fromDatabase: db, duringActivity: "opening newly created database")
        }
        guard db.beginTransaction() else {
            exitWithError(fromDatabase: db, duringActivity: "trxn start while creating settings table")
        }
        do {
            try db.executeUpdate("CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT);", values: nil)
            try db.executeUpdate("INSERT INTO settings (key, value) VALUES (?, ?)", values: ["version", 0])
        } catch let error {
            exitWithError(error, duringActivity: "creating settings table")
        }
        guard db.commit() else {
            exitWithError(fromDatabase: db, duringActivity: "trxn commit while creating settings table")
        }
    }
    
    private static func exitWithError(fromDatabase db: FMDatabase, duringActivity activity: String) -> Never {
        let code = db.lastErrorCode()
        let message = db.lastErrorMessage()
        exitWithErrorMessage("\(code) \(message)", duringActivity: activity)
    }
    
    private static func exitWithError(_ error: Error, duringActivity activity: String) -> Never {
        exitWithErrorMessage(error.localizedDescription, duringActivity: activity)
    }
    
    private static func exitWithErrorMessage(_ message: String, duringActivity activity: String) -> Never {
        Prompt.exitStonks(withMessage: "Database error while \(activity): \(message)")
    }
}
