import FMDB

struct DatabaseKeys {
    static let settings_version = "version"
    
    static let stats_profitNotTransferred = "profit_not_transferred"
}

private enum DatabaseTransferType: String {
    case deposit = "deposit"
    case dividend = "dividend"
    case interest = "interest"
    case withdrawal = "withdrawal"
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
    
    static func allStatementEntries(fromPath path: String, forMonth yearMonth: String) -> [StatementEntry] {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to get statement entries")
        }
        var entries = [StatementEntry]()
        do {
            entries += try statementEntriesFromActiveBuys(fromDatabase: db, forMonth: yearMonth)
            entries += try statementEntriesFromClosedSells(fromDatabase: db, forMonth: yearMonth)
            entries += try statementEntriesFromTransfers(fromDatabse: db, forMonth: yearMonth)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "fetching statement entries")
        }
        entries.sort(by: { $0.date < $1.date })
        for (index, entry) in entries.enumerated() {
            entry.reconciliationId = index + 1
        }
        return entries
    }
    
    private static func statementEntriesFromActiveBuys(fromDatabase db: FMDatabase, forMonth yearMonth: String) throws -> [StatementEntry] {
        let nextYearMonth = DatabaseUtilities.subsequentYearMonth(forYearMonth: yearMonth)
        
        var entries = [StatementEntry]()
        
        let results = try db.executeQuery("SELECT trxn_id, ticker, investment, shares, buy_date, cost_basis FROM transactions WHERE buy_date > ? AND buy_date < ?", values: [yearMonth, nextYearMonth])
        while results.next() {
            let trxn = activeTransaction(fromResultSet: results)
            let activity: StatementEntry.Activity = trxn.ticker == BlockchainAPI.bitcoinSymbol ? .crypto : .buy
            let entry = StatementEntry(trxnId: trxn.trxnId,
                                       symbol: trxn.ticker,
                                       activity: activity,
                                       date: trxn.buyDate,
                                       shares: trxn.shares,
                                       costBasis: trxn.costBasis,
                                       amount: trxn.investment * -1)
            entries.append(entry)
        }
        return entries
    }
    
    private static func statementEntriesFromClosedSells(fromDatabase db: FMDatabase, forMonth yearMonth: String) throws -> [StatementEntry] {
        let nextYearMonth = DatabaseUtilities.subsequentYearMonth(forYearMonth: yearMonth)
        
        var entries = [StatementEntry]()
        
        let results = try db.executeQuery("SELECT trxn_id, ticker, shares, sell_date, sell_price, revenue FROM transactions WHERE sell_date NOT NULL AND sell_date > ? AND sell_date < ?", values: [yearMonth, nextYearMonth])
        while results.next() {
            let trxnId = results.long(forColumn: "trxn_id")
            let ticker = results.string(forColumn: "ticker") ?? Utilities.errorString
            let shares = results.double(forColumn: "shares")
            let sellDate = results.string(forColumn: "sell_date") ?? Utilities.errorString
            let sellPrice = results.double(forColumn: "sell_price")
            let revenue = results.double(forColumn: "revenue")
            let activity: StatementEntry.Activity = ticker == BlockchainAPI.bitcoinSymbol ? .crypto : .sell
            let entry = StatementEntry(trxnId: trxnId,
                                       symbol: ticker,
                                       activity: activity,
                                       date: DatabaseUtilities.date(fromString: sellDate),
                                       shares: shares,
                                       costBasis: sellPrice,
                                       amount: revenue)
            entries.append(entry)
        }
        return entries
    }
    
    private static func statementEntriesFromTransfers(fromDatabse db: FMDatabase, forMonth yearMonth: String) throws -> [StatementEntry] {
        let nextYearMonth = DatabaseUtilities.subsequentYearMonth(forYearMonth: yearMonth)
        
        var entries = [StatementEntry]()
        
        let results = try db.executeQuery("SELECT date, amount, type, source FROM transfers WHERE date > ? AND date < ?", values: [yearMonth, nextYearMonth])
        while results.next() {
            let symbol = results.string(forColumn: "source") ?? ""
            let rawType = results.string(forColumn: "type") ?? "<null>"
            guard let type = DatabaseTransferType(rawValue: rawType) else {
                Prompt.exitStonks(withMessage: "Found unrecognized transfer type of '\(rawType)'")
            }
            let activity: StatementEntry.Activity
            switch type {
            case .deposit:    activity = .ach
            case .dividend:   activity = .cashDividend
            case .interest:   activity = .cashManagementInterest
            case .withdrawal: activity = .ach
            }
            let date = DatabaseUtilities.date(fromString: results.string(forColumn: "date") ?? Utilities.errorString)
            let amount = results.double(forColumn: "amount")
            let entry = StatementEntry(trxnId: nil,
                                       symbol: symbol,
                                       activity: activity,
                                       date: date,
                                       shares: nil,
                                       costBasis: nil,
                                       amount: amount)
            entries.append(entry)
        }
        return entries
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
        let minimumPurchaseAmount = 1.00
        
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: path)

        var pendingAmounts = portfolioGoals(fromPath: path)
        for active in activeTransactions {
            if pendingAmounts.keys.contains(active.ticker) {
                pendingAmounts[active.ticker, default: 0] -= active.investment
            }
        }
        for pending in pendingAmounts.keys {
            if pendingAmounts[pending, default: 0] < minimumPurchaseAmount {
                pendingAmounts.removeValue(forKey: pending)
            }
        }
        
        let buyingPower = DatabaseIO.buyingPower(fromPath: path)
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: path)
        let maxAllowablePurchase = buyingPower - profitNotTransferred
        guard maxAllowablePurchase >= minimumPurchaseAmount else {
            return []
        }
        
        var pendingBuys = [PendingBuy]()
        for (symbol, amount) in pendingAmounts {
            let allowableAmount = min(amount, maxAllowablePurchase)
            let pb = PendingBuy(ticker: symbol, amount: allowableAmount)
            pendingBuys.append(pb)
        }
        return pendingBuys
    }
    
    static func portfolioGoals(fromPath path: String) -> [String: Double] {
        let reinvestmentSplits = DatabaseIO.reinvestmentSplits(fromPath: path)
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: path)

        let cashReadyForReinvestment = DatabaseIO.totalPendingBuys(fromPath: path)
        // Only include existing investments that are in our portfolio goals
        let cashTiedUpInExistingInvestments = activeTransactions.filter({ reinvestmentSplits.map(\.ticker).contains($0.ticker) })
                                                                .map(\.investment)
                                                                .reduce(0, +)
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
                DatabaseTransferType.deposit.rawValue
            ]
            try db.executeUpdate("INSERT INTO transfers (date, amount, type) VALUES (?, ?, ?)", values: values)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording deposit")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording deposit")
        }
    }
    
    static func recordWithdrawal(path: String,
                                 amount: Double,
                                 date: String)
    {
        let negativeAmount = -1 * amount
        guard negativeAmount < 0 else {
            Prompt.exitStonks(withMessage: "DatabaseIO can't withdraw a negative amount!")
        }
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record a withdrawal")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording withdrawal")
        }
        do {
            // Record withdrawal
            let values: [Any] = [
                date,
                negativeAmount,
                DatabaseTransferType.withdrawal.rawValue
            ]
            try db.executeUpdate("INSERT INTO transfers (date, amount, type) VALUES (?, ?, ?)", values: values)
            // Subtract from profit not transferred
            try addToProfitNotTransferred(negativeAmount, inOpenDatabase: db)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording withdrawal")
        }
        guard db.commit() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording withdrawal")
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
                DatabaseTransferType.dividend.rawValue,
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
    
    static func recordInterest(path: String,
                               amount: Double,
                               date: String)
    {
        let db = FMDatabase(path: path)
        guard db.open() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "opening database to record interest")
        }
        guard db.beginTransaction() else {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn start while recording interest")
        }
        do {
            // Record interest
            let values: [Any] = [
                date,
                amount,
                DatabaseTransferType.interest.rawValue
            ]
            try db.executeUpdate("INSERT INTO transfers (date, amount, type) VALUES (?, ?, ?);", values: values)
            // Add interest to profit
            try addToProfitNotTransferred(amount, inOpenDatabase: db)
        } catch let error {
            DatabaseUtilities.exitWithError(error, duringActivity: "recording interest")
        }
        guard db.commit() else  {
            DatabaseUtilities.exitWithError(fromDatabase: db, duringActivity: "trxn commit while recording interest")
        }
    }
}
