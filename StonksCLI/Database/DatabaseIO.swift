import FMDB

struct DatabaseKeys {
    static let settings_version = "version"
    static let transfers_type_deposit = "deposit"
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
            
            // Update the pending buys to account for the buy
            let currentPendingBuys = pendingBuys(fromDatabase: db)
            // TODO: Maybe later, auto-update pending buys by pulling out the spent amount evenly by percentage from the other pending buys
            if currentPendingBuys.map({ $0.ticker }).contains(ticker) {
                let pendingAmount = currentPendingBuys.filter({ $0.ticker == ticker }).first!.amount
                if investment > pendingAmount && !((investment - pendingAmount).isBasicallyZero) {
                    print("You bought \(Formatting.string(forCurrency: investment)), but only \(Formatting.string(forCurrency: pendingAmount)) was pending.")
                    print("This will invalidate your checksum.")
                    print("Use the reset option from the main menu, or edit your pending buys manually.")
                    Prompt.pauseThenContinue()
                }
                let updatedPendingAmount = (pendingAmount - investment).roundToZeroIfLessThanOneCent
                try db.executeUpdate("UPDATE pending_buys SET amount = ? WHERE ticker = ?;", values: [updatedPendingAmount, ticker])
                try deleteEmptyPendingBuys(fromDatabase: db)
            } else {
                print("You bought something that wasn't in your pending buys.")
                print("This will invalidate your checksum.")
                print("Use the reset option from the main menu, or edit your pending buys manually.")
                Prompt.pauseThenContinue()
            }
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
            let currentProfitNotTransferred = profitNotTransferred(fromDatabase: db)
            let newProfit = currentProfitNotTransferred + profit
            try db.executeUpdate("UPDATE stats_and_totals SET value = ? WHERE key = ?;", values: [newProfit, DatabaseKeys.stats_profitNotTransferred])
            
            // Redistribute investment
            let splits = reinvestmentSplits(fromDatabase: db)
            // If we lost money, we can only reinvest what we got back
            let reinvestmentAmount = min(investment, revenue)
            if splits.map({ $0.ticker }).contains(ticker) {
                // If the sell was of a stock that we are actively investing in, just carry over the amount directly
                let pending = pendingBuys(fromDatabase: db)
                let existingPendingAmount = pending.filter({ $0.ticker == ticker }).first!.amount
                let newPendingAmount = existingPendingAmount + reinvestmentAmount
                try db.executeUpdate("UPDATE pending_buys SET amount = ? WHERE ticker = ?;", values: [newPendingAmount, ticker])
            } else {
                // If the sell was of something that's not in our splits, redistribute the amount evenly
                try executeReinvestmentSplit(inDatabase: db, amount: reinvestmentAmount)
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording sell")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording sell")
        }
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
    
    static func profitNotTransferred(fromPath path: String) -> Double {
        let db = FMDatabase(path: path)
        return profitNotTransferred(fromDatabase: db)
    }
    
    private static func profitNotTransferred(fromDatabase db: FMDatabase) -> Double {
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get total profit not transferred")
        }
        let profit: Double
        do {
            let results = try db.executeQuery("SELECT value FROM stats_and_totals WHERE key = ?;", values: [DatabaseKeys.stats_profitNotTransferred])
            guard results.next() else {
                Prompt.exitStonks(withMessage: "Couldn't get next row in totalProfitNotTransferred()")
            }
            profit = results.double(forColumn: "value")
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching total profit not transferred")
        }
        return profit
    }
    
    static func totalPendingBuys(fromPath path: String) -> Double {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get total pending buys")
        }
        let pendingBuyTotal: Double
        do {
            let results = try db.executeQuery("SELECT SUM(amount) AS amount FROM pending_buys;", values: nil)
            guard results.next() else {
                Prompt.exitStonks(withMessage: "Couldn't get next row in totalPendingBuys()")
            }
            pendingBuyTotal = results.double(forColumn: "amount")
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching total pending buys")
        }
        return pendingBuyTotal
    }
    
    // MARK: - Pending buys and splits
    
    static func pendingBuys(fromPath path: String) -> [PendingBuy] {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to fetch pending buys")
        }
        return pendingBuys(fromDatabase: db)
    }
    
    // TODO: This should really return a [String : Double].
    private static func pendingBuys(fromDatabase db: FMDatabase) -> [PendingBuy] {
        var buys = [PendingBuy]()
        do {
            let results = try db.executeQuery("SELECT ticker, amount FROM pending_buys;", values: nil)
            while results.next() {
                let ticker = results.string(forColumn: "ticker") ?? Utilities.errorString
                let amount = results.double(forColumn: "amount")
                buys.append(PendingBuy(ticker: ticker, amount: amount))
            }
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching pending buys")
        }
        return buys
    }
    
    static func resetPendingBuys(inPath path: String) {
        let transferBalance = DatabaseIO.transferBalance(fromPath: path)
        let (totalInvestment, totalRevenue) = DatabaseIO.totalInvestmentAndRevenue(fromPath: path)
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: path)
        let availableBuyingPower = (transferBalance - totalInvestment + totalRevenue - profitNotTransferred).roundToZeroIfLessThanOneCent
        
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to reset pending buys")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while resetting pending buys")
        }
        do {
            try db.executeUpdate("DELETE FROM pending_buys;", values: nil)
            try executeReinvestmentSplit(inDatabase: db, amount: availableBuyingPower)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "resetting pending buys")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while resetting pending buys")
        }
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
            let results = try db.executeQuery("SELECT ticker, weight FROM reinvestment_splits;", values: nil)
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
    
    private static func executeReinvestmentSplit(inDatabase db: FMDatabase, amount: Double) throws {
        let splits = reinvestmentSplits(fromDatabase: db)
        
        // TODO: There is probably a cleaner and Swift-ier way to write all this, but this will do for now.
        let currentPendingBuys = pendingBuys(fromDatabase: db)
        var pendingBuyDictionary = [String : Double]()
        currentPendingBuys.forEach { buy in
            pendingBuyDictionary[buy.ticker] = buy.amount
        }
        guard pendingBuyDictionary.count == currentPendingBuys.count else {
            Prompt.exitStonks(withMessage: "Your pending buys have duplicate symbols. Please resolve this manually.")
        }
        
        try splits.forEach { split in
            let symbol = split.ticker
            let amountToAdd = amount * split.percentage
            if pendingBuyDictionary.keys.contains(symbol) {
                let newAmount = pendingBuyDictionary[symbol, default: 0] + amountToAdd
                try db.executeUpdate("UPDATE pending_buys SET amount = ? WHERE ticker = ?;", values: [newAmount, symbol])
            } else {
                try db.executeUpdate("INSERT INTO pending_buys (ticker, amount) VALUES (?, ?);", values: [symbol, amountToAdd])
            }
        }
        try deleteEmptyPendingBuys(fromDatabase: db)
    }
    
    private static func deleteEmptyPendingBuys(fromDatabase db: FMDatabase) throws {
        try db.executeUpdate("DELETE FROM pending_buys WHERE amount < ?", values: [0.01])
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
            try executeReinvestmentSplit(inDatabase: db, amount: amount)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording deposit")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording deposit")
        }
    }
}
