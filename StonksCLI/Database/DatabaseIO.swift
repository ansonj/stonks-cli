import FMDB

struct DatabaseKeys {
    static let settings_version = "version"
    
    static let transfers_type_deposit = "deposit"
    static let transfers_type_dividend = "dividend"
    
    static let stats_profitNotTransferred = "profit_not_transferred"
}

struct DatabaseIO {
    // TODO: Would be nice to organize the functions in this file a bit more, if you can
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
            // Record the buy transaction
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
            let results = try db.executeQuery("SELECT trxn_id, ticker, investment, shares, buy_date, cost_basis FROM transactions WHERE sell_date IS NULL", values: nil)
            while results.next() {
                let newTransaction = activeTransaction(fromResultSet: results)
                transactions.append(newTransaction)
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "selecting active transactions")
        }
        return transactions
    }
    
    static func activeTransaction(fromPath path: String, withId queryTrxnId: Int) -> ActiveBuyTransaction? {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to find active transaction with ID")
        }
        let transaction: ActiveBuyTransaction?
        do {
            let results = try db.executeQuery("SELECT trxn_id, ticker, investment, shares, buy_date, cost_basis FROM transactions WHERE sell_date IS NULL AND trxn_id = ?;", values: [queryTrxnId])
            if results.next() {
                transaction = activeTransaction(fromResultSet: results)
            } else {
                transaction = nil
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "finding active transaction with ID")
        }
        return transaction
    }
    
    private static func activeTransaction(fromResultSet results: FMResultSet) -> ActiveBuyTransaction {
        let trxnId = results.long(forColumn: "trxn_id")
        let ticker = results.string(forColumn: "ticker") ?? Utilities.errorString
        let investment = results.double(forColumn: "investment")
        let shares = results.double(forColumn: "shares")
        let date = results.string(forColumn: "buy_date") ?? Utilities.errorString
        let costBasis = results.double(forColumn: "cost_basis")
        let newTransaction = ActiveBuyTransaction(trxnId: trxnId,
                                                  ticker: ticker,
                                                  investment: investment,
                                                  shares: shares,
                                                  buyDate: DatabaseUtilities.date(fromString: date),
                                                  costBasis: costBasis)
        return newTransaction
    }
    
    static func recordSell(path: String,
                           trxnId: Int,
                           ticker: String,
                           investment: Double,
                           sellDate: String,
                           sellPrice: Double,
                           revenue: Double,
                           profit: Double,
                           returnPercentage: Double,
                           heldDays: Int)
    {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record sell")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording sell")
        }
        do {
            // Update the transaction with the sale details.
            let values: [Any] = [
                sellDate,
                sellPrice,
                revenue,
                returnPercentage,
                profit,
                heldDays,
                trxnId
            ]
            try db.executeUpdate("UPDATE transactions SET sell_date = ?, sell_price = ?, revenue = ?, return_percentage = ?, profit = ?, held_days = ? WHERE trxn_id = ?;", values: values)
            
            // Record profit
            try addToProfitNotTransferred(profit, inOpenDatabase: db)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording sell")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording sell")
        }
    }
    
    private static func addToProfitNotTransferred(_ amount: Double,
                                                  inOpenDatabase db: FMDatabase) throws
    {
        let currentProfitNotTransferred = try profitNotTransferred(fromOpenDatabase: db)
        let newProfit = currentProfitNotTransferred + amount
        try db.executeUpdate("UPDATE stats_and_totals SET value = ? WHERE key = ?;", values: [newProfit, DatabaseKeys.stats_profitNotTransferred])
    }
    
    // MARK: - Checksum
    
    static func transferBalance(fromPath path: String) -> Double {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get transfer balance")
        }
        let balance: Double
        do {
            let results = try db.executeQuery("SELECT SUM(amount) AS amount FROM transfers;", values: nil)
            guard results.next() else {
                Prompt.exitStonks(withMessage: "Couldn't get next row in transferBalance()")
            }
            balance = results.double(forColumn: "amount")
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching transfer balance")
        }
        return balance
    }
    
    static func totalInvestmentAndRevenue(fromPath path: String) -> (investment: Double, revenue: Double) {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get total investment and revenue")
        }
        let investment: Double
        let revenue: Double
        do {
            let results = try db.executeQuery("SELECT SUM(investment) AS investment, SUM(revenue) AS revenue FROM transactions;", values: nil)
            guard results.next() else {
                Prompt.exitStonks(withMessage: "Couldn't get next row in totalInvestmentAndRevenue()")
            }
            investment = results.double(forColumn: "investment")
            revenue = results.double(forColumn: "revenue")
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching total investment and revenue")
        }
        return (investment: investment, revenue: revenue)
    }
    
    static func buyingPower(fromPath path: String) -> Double {
        let transferBalance = DatabaseIO.transferBalance(fromPath: path)
        let (totalInvestment, totalRevenue) = DatabaseIO.totalInvestmentAndRevenue(fromPath: path)
        let buyingPower = transferBalance - totalInvestment + totalRevenue
        return buyingPower
    }
    
    static func profitNotTransferred(fromPath path: String) -> Double {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get total profit not transferred")
        }
        let profit: Double
        do {
            profit = try profitNotTransferred(fromOpenDatabase: db)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching total profit not transferred")
        }
        return profit
    }
    
    private static func profitNotTransferred(fromOpenDatabase db: FMDatabase) throws -> Double {
        let results = try db.executeQuery("SELECT value FROM stats_and_totals WHERE key = ?;", values: [DatabaseKeys.stats_profitNotTransferred])
        guard results.next() else {
            Prompt.exitStonks(withMessage: "Couldn't get next row in totalProfitNotTransferred()")
        }
        let profit = results.double(forColumn: "value")
        return profit
    }
    
    static func totalPendingBuys(fromPath path: String) -> Double {
        let buyingPower = DatabaseIO.buyingPower(fromPath: path)
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: path)
        let totalPendingBuys = buyingPower - profitNotTransferred
        return totalPendingBuys
    }
    
    // MARK: - Pending buys and splits
    
    static func pendingBuys(fromPath path: String) -> [PendingBuy] {
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: path)

        var pendingAmounts = portfolioGoals(fromPath: path)
        for active in activeTransactions {
            if pendingAmounts.keys.contains(active.ticker) {
                pendingAmounts[active.ticker, default: 0] -= active.investment
            }
        }
        for pending in pendingAmounts.keys {
            if pendingAmounts[pending, default: 0] <= 0 {
                pendingAmounts.removeValue(forKey: pending)
            }
        }
        
        var pendingBuys = [PendingBuy]()
        for (symbol, amount) in pendingAmounts {
            let pb = PendingBuy(ticker: symbol, amount: amount)
            pendingBuys.append(pb)
        }
        return pendingBuys
    }
    
    static func portfolioGoals(fromPath path: String) -> [String: Double] {
        let reinvestmentSplits = DatabaseIO.reinvestmentSplits(fromPath: path)
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: path)

        let cashReadyForReinvestment = DatabaseIO.totalPendingBuys(fromPath: path)
        let cashTiedUpInExistingInvestments = activeTransactions.map(\.investment).reduce(0, +)
        let totalPortfolioSize = cashReadyForReinvestment + cashTiedUpInExistingInvestments
        
        var portfolioGoals = [String: Double]()
        for portfolioMember in reinvestmentSplits {
            let goalAmount = portfolioMember.percentage * totalPortfolioSize
            portfolioGoals[portfolioMember.ticker] = goalAmount
        }
        
        return portfolioGoals
    }
    
    static func reinvestmentSplits(fromPath path: String) -> [Split] {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to fetch splits")
        }
        return reinvestmentSplits(fromDatabase: db)
    }
    
    private static func reinvestmentSplits(fromDatabase db: FMDatabase) -> [Split] {
        var databaseSplits = [String : Double]()
        var rowCount = 0
        do {
            let results = try db.executeQuery("SELECT ticker, weight FROM reinvestment_splits WHERE weight > 0;", values: nil)
            while results.next() {
                rowCount += 1
                let ticker = results.string(forColumn: "ticker") ?? Utilities.errorString
                let weight = results.double(forColumn: "weight")
                databaseSplits[ticker] = weight
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching splits")
        }
        let totalWeight = databaseSplits.values.reduce(0, +)
        var completedSplits = [Split]()
        databaseSplits.forEach { (ticker: String, weight: Double) in
            completedSplits.append(Split(ticker: ticker,
                                         weight: weight,
                                         percentage: weight / totalWeight))
        }
        guard completedSplits.count == rowCount else {
            Prompt.exitStonks(withMessage: "Double-check your splits. You may have duplicate symbols.")
        }
        return completedSplits
    }
    
    static func addDefaultSplits(toPath path: String) {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to add default splits")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while adding default splits")
        }
        do {
            let samples: [String : Double] = [
                "AAPL" : 5,
                "MSFT" : 3,
                "TSLA" : 2
            ]
            try samples.forEach { (ticker, weight) in
                try db.executeUpdate("INSERT INTO reinvestment_splits (ticker, weight) VALUES (?, ?)", values: [ticker, weight])
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "adding default splits")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while adding default splits")
        }
    }
    
    // MARK: - Transfers
    
    static func recordDeposit(path: String,
                              amount: Double,
                              date: String)
    {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record a deposit")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording deposit")
        }
        do {
            let values: [Any] = [
                date,
                amount,
                DatabaseKeys.transfers_type_deposit
            ]
            try db.executeUpdate("INSERT INTO transfers (date, amount, type) VALUES (?, ?, ?)", values: values)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording deposit")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording deposit")
        }
    }
    
    static func recordDividend(path: String,
                               amount: Double,
                               date: String,
                               symbol: String)
    {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record a dividend")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording dividend")
        }
        do {
            // Record dividend
            let values: [Any] = [
                date,
                amount,
                DatabaseKeys.transfers_type_dividend,
                symbol
            ]
            try db.executeUpdate("INSERT INTO transfers (date, amount, type, source) VALUES (?, ?, ?, ?);", values: values)
            // Add dividend to profit
            try addToProfitNotTransferred(amount, inOpenDatabase: db)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording dividend")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording dividend")
        }
    }
}
