import FMDB

struct DatabaseFileManager {
    static func verifyDatabase(atPath path: String) {
        // TODO: It would be nice to reuse a single database connection here, if that makes sense
        createDatabaseIfNeeded(atPath: path)
        runDatabaseMigrationsIfNeeded(atPath: path)
    }
    
    private static func createDatabaseIfNeeded(atPath path: String) {
        if FileManager.default.isReadableFile(atPath: path) {
           return
        }
        Logger.log("Creating database file...")
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
    
    private static func runDatabaseMigrationsIfNeeded(atPath path: String) {
        let db = FMDatabase(path: path)
        guard db.open() else {
            exitWithError(fromDatabase: db, duringActivity: "opening database for migration")
        }
        func currentVersion() -> Int {
            do {
                let resultSet = try db.executeQuery("SELECT value FROM settings WHERE key = 'version'", values: nil)
                resultSet.next()
                let version = resultSet.int(forColumn: "value")
                return Int(version)
            } catch let error {
                exitWithError(error, duringActivity: "retrieving db version number")
            }
        }
        guard let maxVersion = migrations.keys.max() else {
            Prompt.exitStonks(withMessage: "Couldn't get max migration version number")
        }
        if currentVersion() > maxVersion {
            Prompt.exitStonks(withMessage: "Database was at version \(currentVersion()), but max known version is \(maxVersion)")
        }
        if currentVersion() == maxVersion {
            return
        }
        Logger.log("Running database migrations...")
        while currentVersion() < maxVersion {
            let nextVersion = currentVersion() + 1
            guard db.beginTransaction() else {
                exitWithError(fromDatabase: db, duringActivity: "trxn start while doing migration to version \(nextVersion)")
            }
            guard let nextMigrationScript = migrations[nextVersion] else {
                Prompt.exitStonks(withMessage: "Couldn't get migration script for \(nextVersion) upgrade")
            }
            do {
                try db.executeUpdate(nextMigrationScript, values: nil)
                try db.executeUpdate("UPDATE settings SET value = ? WHERE key = 'version'", values: [nextVersion])
            } catch let error {
                exitWithError(error, duringActivity: "migrating to version \(nextVersion)")
            }
            guard db.commit() else {
                exitWithError(fromDatabase: db, duringActivity: "trxn commit while migrating to version \(nextVersion)")
            }
        }
    }
    
    // MARK: Database helpers
    
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

private let migrations: [Int : String] = [
    1: """
    CREATE TABLE transactions(ticker TEXT NOT NULL,
                              investment NUMERIC NOT NULL,
                              shares NUMERIC NOT NULL,
                              buy_date TEXT NOT NULL,
                              sell_date TEXT,
                              sell_price NUMERIC,
                              profit_withdrawn INTEGER);
    """,
]
