import Foundation

struct MainFlow: Flow {
    let configFile: ConfigFile
    let priceCache: PriceCache
    
    func run() {
        var lastInputErrorMessage: String? = nil
        while true {
            printActiveTable()
            printBuyingPowerChecksum()
            printPendingBuys()
            print("Main menu")
            print("    (b)uy")
            print("    (t)ransfer")
            print("    view (r)einvestment splits")
            print("    (q)uit")
            print()
            let promptString: String
            if lastInputErrorMessage != nil {
                promptString = "Choose action (\(lastInputErrorMessage!)):"
                lastInputErrorMessage = nil
            } else {
                promptString = "Choose action:"
            }
            // TODO: Gracefully handle input of Ctrl+D
            let selection = Prompt.readString(withMessage: promptString)
            print()
            switch selection.first {
            case nil:
                // Allow pressing enter to refresh table
                break
            case "b":
                let buy = BuyFlow(configFile: configFile)
                buy.run()
            case "t":
                let transfer = TransferFlow(configFile: configFile)
                transfer.run()
            case "r":
                let splits = SplitsFlow(configFile: configFile)
                splits.run()
            case "q":
                exit(0)
            default:
                lastInputErrorMessage = "'\(selection)' is not an option"
            }
        }
    }
    
    private func printActiveTable() {
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: configFile.databasePath())
        
        priceCache.primeCache(forTickers: Set<String>(activeTransactions.map({ $0.ticker })))
        
        var displayRows = activeTransactions.map {
            ActiveDisplayRow(activeBuyTransaction: $0, priceSource: priceCache)
        }
        // Fill in averageReturnPercentage, which we can't calculate individually
        displayRows.forEach { row in
            let matchingTrxns = displayRows.filter { $0.ticker == row.ticker }
            let totalInvestment = matchingTrxns.reduce(into: 0, { $0 += $1.investment })
            let totalValue = matchingTrxns.reduce(into: 0, { $0 += $1.currentValue })
            row.averageReturnPercentage = (totalValue - totalInvestment) / totalInvestment
        }
        displayRows.sort { (lhs: ActiveDisplayRow, rhs: ActiveDisplayRow) -> Bool in
            // return true if lhs should come before rhs
            if lhs.averageReturnPercentage > rhs.averageReturnPercentage {
                return true
            } else if lhs.averageReturnPercentage < rhs.averageReturnPercentage {
                return false
            }
            if lhs.ticker < rhs.ticker {
                return true
            } else if lhs.ticker > rhs.ticker {
                return false
            }
            return lhs.age > rhs.age
        }
        
        let colorPercentage = { (p: Double) -> TerminalTextColor in
            // TODO: These will become settings someday
            let almostReadyToSellThreshold = 3.5 / 100.0
            let sellThreshold = 5 / 100.0
            if p < 0 {
                return .red
            } else if 0 <= p && p < almostReadyToSellThreshold {
                return .black
            } else if almostReadyToSellThreshold <= p && p < sellThreshold {
                return .yellow
            } else {
                assert(sellThreshold <= p, "Developer or floating point error")
                return .green
            }
        }
        let colorProfit = { (n: Double) -> TerminalTextColor in
            if n < 0 {
                return .red
            } else {
                return .black
            }
        }
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Company Name", alignment: .left),
            HeaderCell("Investment", alignment: .right),
            HeaderCell("Current Price", alignment: .right),
            HeaderCell("Current Return", alignment: .right),
            HeaderCell("Current Profit", alignment: .right),
            HeaderCell("Age", alignment: .right),
            HeaderCell("Avg. Return", alignment: .right),
        ]
        let rows = displayRows.map { row -> [TableCell] in
            let currentReturnColor = colorPercentage(row.currentReturnPercentage)
            let currentProfitColor = colorProfit(row.profit)
            let avgReturnColor = colorPercentage(row.averageReturnPercentage)
            return [
                TableCell(row.ticker, color: currentReturnColor),
                TableCell(row.companyName),
                TableCell(Formatting.string(forCurrency: row.investment)),
                TableCell(Formatting.string(forCurrency: row.currentPrice)),
                TableCell(Formatting.string(forPercentage: row.currentReturnPercentage), color: currentReturnColor),
                TableCell(Formatting.string(forCurrency: row.profit), color: currentProfitColor),
                TableCell(row.age.description),
                TableCell(Formatting.string(forPercentage: row.averageReturnPercentage), color: avgReturnColor)
            ]
        }
        let table = Table.renderTable(withHeaders: headers,
                                      rows: rows)
        print(table)
        print()
    }
    
    private func printBuyingPowerChecksum() {
        let databasePath = configFile.databasePath()
        let transferBalance = DatabaseIO.transferBalance(fromPath: databasePath)
        let (totalInvestment, totalRevenue) = DatabaseIO.totalInvestmentAndRevenue(fromPath: databasePath)
        let deducedBuyingPower = transferBalance - totalInvestment + totalRevenue
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: databasePath)
        let totalPendingBuys = DatabaseIO.totalPendingBuys(fromPath: databasePath)
        let shouldBeZero = deducedBuyingPower - profitNotTransferred - totalPendingBuys
        
        let transferBalance_string = Formatting.string(forCurrency: transferBalance)
        let totalInvestment_string = Formatting.string(forCurrency: totalInvestment)
        let totalRevenue_string = Formatting.string(forCurrency: totalRevenue)
        let buyingPower_string = Formatting.string(forCurrency: deducedBuyingPower)
        print("Transfer balance - buys + revenue = buying power")
        print("\t", transferBalance_string, "-", totalInvestment_string, "+", totalRevenue_string, "=", buyingPower_string)
        let profitNotTransferred_string = Formatting.string(forCurrency: profitNotTransferred)
        let totalPendingBuys_string = Formatting.string(forCurrency: totalPendingBuys)
        let shouldBeZero_string = Formatting.string(forCurrency: shouldBeZero)
        print("Buying power - profit not transferred - pending buys = zero")
        print("\t", buyingPower_string, "-", profitNotTransferred_string, "-", totalPendingBuys_string, "=", shouldBeZero_string)
        print()
    }
    
    private func printPendingBuys() {
        let pendingBuys = DatabaseIO.pendingBuys(fromPath: configFile.databasePath())
        guard pendingBuys.count > 0 else {
            print("No pending buys.")
            print()
            return
        }
        priceCache.primeCache(forTickers: Set<String>(pendingBuys.map({ $0.ticker })))
        let displayRows = pendingBuys.map { PendingBuyDisplayRow(pendingBuy: $0,
                                                                 priceSource: priceCache) }
                                     .sorted(by: { $0.amount > $1.amount })
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Amount", alignment: .right),
            HeaderCell("Company Name", alignment: .left)
        ]
        let rows = displayRows.map {
            [
                TableCell($0.ticker),
                TableCell(Formatting.string(forCurrency: $0.amount)),
                TableCell($0.companyName)
            ]
        }
        print("Pending buys:")
        print(Table.renderTable(withHeaders: headers, rows: rows))
        print()
    }
}

private class ActiveDisplayRow {
    let ticker: String
    let companyName: String
    let investment: Double
    let currentPrice: Double
    let currentValue: Double // No need to display this one, but it's helpful for math
    let currentReturnPercentage: Double
    let profit: Double
    let age: Int
    var averageReturnPercentage: Double
    
    init(activeBuyTransaction trxn: ActiveBuyTransaction, priceSource: PriceCache) {
        let info = priceSource.info(forTicker: trxn.ticker)
        
        self.ticker = trxn.ticker
        self.companyName = info.companyName
        self.investment = trxn.investment
        self.currentPrice = info.price
        self.currentValue = currentPrice * trxn.shares
        self.currentReturnPercentage = (currentValue - investment) / investment
        self.profit = currentValue - investment
        // FIXME: There is a bug here; need to ensure these dates have the same time
        self.age = Calendar.current.dateComponents([.day], from: trxn.buyDate, to: Date()).day ?? -1
        self.averageReturnPercentage = 0 // Will be filled in later
    }
}

private struct PendingBuyDisplayRow {
    let ticker: String
    let amount: Double
    let companyName: String
    
    init(pendingBuy: PendingBuy, priceSource: PriceCache) {
        self.ticker = pendingBuy.ticker
        self.amount = pendingBuy.amount
        self.companyName = priceSource.info(forTicker: pendingBuy.ticker).companyName
    }
}
