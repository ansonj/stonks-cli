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
    
    static func activeTransactions(fromPath path: String) -> [ActiveBuyTransaction] {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to list active transactions")
        }
        var transactions = [ActiveBuyTransaction]()
        do {
            let results = try db.executeQuery("SELECT ticker, investment, shares, buy_date, cost_basis FROM transactions WHERE sell_date IS NULL", values: nil)
            while results.next() {
                let ticker = results.string(forColumn: "ticker") ?? "ERROR"
                let investment = results.double(forColumn: "investment")
                let shares = results.double(forColumn: "shares")
                let date = results.string(forColumn: "buy_date") ?? "ERROR"
                let costBasis = results.double(forColumn: "cost_basis")
                let newTransaction = ActiveBuyTransaction(ticker: ticker,
                                                          investment: investment,
                                                          shares: shares,
                                                          buyDate: DatabaseUtilities.date(fromString: date),
                                                          costBasis: costBasis)
                transactions.append(newTransaction)
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "selecting active transactions")
        }
        return transactions
    }
    
    // MARK: - Checksum
    
    static func transferBalance(fromPath path: String) -> Double {
        return 0
    }
    
    static func totalInvestmentAndRevenue(fromPath path: String) -> (investment: Double, revenue: Double) {
        return (investment: 0, revenue: 0)
    }
    
    static func totalProfitNotTransferred(fromPath path: String) -> Double {
        return 0
    }
    
    static func totalPendingBuys(fromPath path: String) -> Double {
        return 0
    }
    
    // MARK: -
}
