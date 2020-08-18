import FMDB

struct DatabaseIO {
    static func recordBuy(path: String,
                          ticker: String,
                          investment: Double,
                          shares: Double,
                          date: String)
    {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record a buy")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording buy")
        }
        do {
            let values: [Any] = [
                ticker,
                investment,
                shares,
                date,
                investment / shares
            ]
            try db.executeUpdate("INSERT INTO transactions (ticker, investment, shares, buy_date, cost_basis) VALUES (?, ?, ?, ?, ?)", values: values)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording buy")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording buy")
        }
    }
}
