import FMDB

struct DatabaseFileManager {
    static func verifyDatabase(atPath path: String) {
        // TODO: It would be nice to reuse a single database connection here, if that makes sense
        createDatabaseIfNeeded(atPath: path)
        runDatabaseMigrationsIfNeeded(atPath: path)
        verifySplitsExist(atPath: path)
        checkForDemoDatabaseAndFillIfNeeded(atPath: path)
    }
    
    private static func createDatabaseIfNeeded(atPath path: String) {
        if FileManager.default.isReadableFile(atPath: path) {
           return
        }
        Logger.log("Creating database file...")
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening newly created database")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while creating settings table")
        }
        do {
            try db.executeUpdate("CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT);", values: nil)
            try db.executeUpdate("INSERT INTO settings (key, value) VALUES (?, ?)", values: [DatabaseKeys.settings_version, 0])
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "creating settings table")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while creating settings table")
        }
    }
    
    private static func runDatabaseMigrationsIfNeeded(atPath path: String) {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database for migration")
        }
        func currentVersion() -> Int {
            do {
                let resultSet = try db.executeQuery("SELECT value FROM settings WHERE key = ?", values: [DatabaseKeys.settings_version])
                resultSet.next()
                let version = resultSet.int(forColumn: "value")
                return Int(version)
            } catch let error {
                DatabaseUtilities.exitWithError(error, duringActivity: "retrieving db version number")
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
                DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while doing migration to version \(nextVersion)")
            }
            guard let nextMigrationScript = migrations[nextVersion] else {
                Prompt.exitStonks(withMessage: "Couldn't get migration script for \(nextVersion) upgrade")
            }
            do {
                try db.executeUpdate(nextMigrationScript, values: nil)
                try db.executeUpdate("UPDATE settings SET value = ? WHERE key = ?", values: [nextVersion, DatabaseKeys.settings_version])
            } catch let error {
                DatabaseUtilities.exitWithError(error, duringActivity: "migrating to version \(nextVersion)")
            }
            guard db.commit() else {
                DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while migrating to version \(nextVersion)")
            }
        }
    }
    
    private static func verifySplitsExist(atPath path: String) {
        // TODO: If/when we support editing splits, replace this code.
        if DatabaseIO.reinvestmentSplits(fromPath: path).count > 0 {
            return
        } else {
            DatabaseIO.addDefaultSplits(toPath: path)
            Logger.log("Adding sample splits...")
            if !databasePathIsDemo(path) {
                print("   I've added some sample splits to the reinvestment_splits table in your database.")
                print("   Replace these with the investments of your choice.")
                print("   Pick what stocks you want to invest in and give them weights.")
                print("   The weights don't have to add up to 100.")
                print("   Every deposit into your investment account will be allocated between the splits according to the weights.")
                Prompt.pauseThenContinue()
            }
            print()
        }
    }
    
    private static func checkForDemoDatabaseAndFillIfNeeded(atPath path: String) {
        guard databasePathIsDemo(path),
              !DatabaseIO.databaseContainsTransfersOrActivity(atPath: path)
        else {
            return
        }
        DatabaseIO.addDemoTransfersAndActivity(toPath: path)
    }
    
    private static func databasePathIsDemo(_ path: String) -> Bool {
        return path.hasSuffix("demo.sqlite")
    }
}

private let migrations: [Int : String] = [
    // Must be only one statement per migration.
    1: """
    CREATE TABLE transactions(trxn_id INTEGER PRIMARY KEY,
                              ticker TEXT NOT NULL,
                              investment NUMERIC NOT NULL,
                              shares NUMERIC NOT NULL,
                              buy_date TEXT NOT NULL,
                              cost_basis NUMERIC NOT NULL,
                              sell_date TEXT,
                              sell_price NUMERIC,
                              revenue NUMERIC,
                              return_percentage NUMERIC,
                              profit NUMERIC,
                              held_days INTEGER);
    """,
    2: """
    CREATE TABLE reinvestment_splits(ticker TEXT NOT NULL,
                                     weight NUMERIC NOT NULL);
    """,
    3: """
    CREATE TABLE pending_buys(ticker TEXT NOT NULL,
                              amount NUMERIC NOT NULL);
    """,
    4: """
    CREATE TABLE transfers(date TEXT NOT NULL,
                           amount NUMERIC NOT NULL,
                           source TEXT NOT NULL);
    """,
    5: """
    CREATE TABLE stats_and_totals(key TEXT NOT NULL,
                                  value NUMERIC NOT NULL);
    """,
    6: """
    INSERT INTO stats_and_totals VALUES ("\(DatabaseKeys.stats_profitNotTransferred)", 0);
    """,
    7: """
    ALTER TABLE transfers RENAME COLUMN source TO type;
    """,
    8: """
    ALTER TABLE transfers ADD COLUMN source TEXT;
    """,
    9: """
    DROP TABLE pending_buys;
    """,
]
