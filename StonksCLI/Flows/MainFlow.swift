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
            printProfitNotTransferred()
            print("Main menu")
            print("    (b)uy")
            print("    (s)ell")
            print("    (t)ransfer")
            print("    view (p)ortfolio goals")
            print("    (r)econciliation view")
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
            case "s":
                let sell = SellFlow(configFile: configFile, priceCache: priceCache)
                sell.run()
            case "t":
                let transfer = TransferFlow(configFile: configFile)
                transfer.run()
            case "p":
                let splits = SplitsFlow(configFile: configFile)
                splits.run()
            case "r":
                let statements = StatementsFlow(configFile: configFile)
                statements.run()
            case "q":
                exit(0)
            default:
                lastInputErrorMessage = "'\(selection)' is not an option"
            }
        }
    }
    
    private func printActiveTable() {
        let displayRows = FlowUtilities.activeTransactionDisplayRows(fromPath: configFile.databasePath(), usingPriceCache: priceCache)
        
        let reinvestmentSymbols = DatabaseIO.reinvestmentSplits(fromPath: configFile.databasePath()).map { $0.ticker }
        let (headers, rows) = FlowUtilities.tableHeadersAndRows(forDisplayRows: displayRows,
                                                                markSellableRows: true,
                                                                reinvestmentSymbols: reinvestmentSymbols)
        let table = Table.renderTable(withHeaders: headers,
                                      rows: rows)
        print(table)
        if displayRows.count == 0 {
            print("No active buys.")
        }
        print()
    }
    
    private func printBuyingPowerChecksum() {
        let databasePath = configFile.databasePath()
        let transferBalance = DatabaseIO.transferBalance(fromPath: databasePath)
        let (totalInvestment, totalRevenue) = DatabaseIO.totalInvestmentAndRevenue(fromPath: databasePath)
        let buyingPower = DatabaseIO.buyingPower(fromPath: databasePath)
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: databasePath)
        // TODO: Rename these variables so they make sense with the new portfolio autobalancer
        let totalPendingBuys = DatabaseIO.totalPendingBuys(fromPath: databasePath)
        let shouldBeZero = buyingPower - profitNotTransferred - totalPendingBuys
        
        let transferBalance_string = Formatting.string(forCurrency: transferBalance)
        let totalInvestment_string = Formatting.string(forCurrency: totalInvestment)
        let totalRevenue_string = Formatting.string(forCurrency: totalRevenue)
        let buyingPower_string = Formatting.string(forCurrency: buyingPower)
        print("Transfer balance - buys + revenue = buying power")
        print("\t", transferBalance_string, "-", totalInvestment_string, "+", totalRevenue_string, "=", buyingPower_string)
        let profitNotTransferred_string = Formatting.string(forCurrency: profitNotTransferred)
        let totalPendingBuys_string = Formatting.string(forCurrency: totalPendingBuys)
        let shouldBeZero_string = Formatting.string(forCurrency: shouldBeZero)
        let indicator = shouldBeZero.isBasicallyZero.emoji
        print("Buying power - profit not transferred - cash ready for reinvestment = zero")
        print("\t", buyingPower_string, "-", profitNotTransferred_string, "-", totalPendingBuys_string, "=", shouldBeZero_string, indicator)
        // TODO: Once per execution, print an explanation of a red indicator means, and what to do about it (and pause before continuing)
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
                                     .sorted(by: { $0.changeToday < $1.changeToday })
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Amount", alignment: .right),
            HeaderCell("∆ Today", alignment: .right),
            HeaderCell("Company Name", alignment: .left)
        ]
        let rows = displayRows.map { row -> [TableCell] in
            let deltaColor: TerminalTextColor = row.changeToday < 0 ? .red : .black
            return [
                TableCell(row.ticker),
                TableCell(Formatting.string(forCurrency: row.amount)),
                TableCell(Formatting.string(forPercentage: row.changeToday), color: deltaColor),
                TableCell(row.companyName)
            ]
        }
        print("Pending buys:")
        print(Table.renderTable(withHeaders: headers, rows: rows))
        print()
    }
    
    private func printProfitNotTransferred() {
        let profit = DatabaseIO.profitNotTransferred(fromPath: configFile.databasePath())
        guard profit > 0 else {
            return
        }
        print("Profit ready to withdraw:", Formatting.string(forCurrency: profit))
        print()
    }
}

private struct PendingBuyDisplayRow {
    let ticker: String
    let amount: Double
    let changeToday: Double
    let companyName: String
    
    init(pendingBuy: PendingBuy, priceSource: PriceCache) {
        self.ticker = pendingBuy.ticker
        self.amount = pendingBuy.amount
        let info = priceSource.info(forTicker: pendingBuy.ticker)
        self.changeToday = info.todaysChangePercentage
        self.companyName = info.companyName
    }
}
