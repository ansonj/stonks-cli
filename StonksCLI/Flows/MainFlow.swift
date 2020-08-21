import Foundation

struct MainFlow: Flow {
    let configFile: ConfigFile
    let priceCache: PriceCache
    
    func run() {
        var lastInputErrorMessage: String? = nil
        while true {
            printActiveTable()
            // TODO: Print buying power checksum
            // TODO: Print pending buys list
            printMainMenu()
            let promptString: String
            if lastInputErrorMessage != nil {
                promptString = "Choose action (\(lastInputErrorMessage!)):"
                lastInputErrorMessage = nil
            } else {
                promptString = "Choose action:"
            }
            // TODO: Gracefully handle input of Ctrl+D
            let selection = Prompt.readString(withMessage: promptString)
            switch selection.first {
            case nil:
                // Allow pressing enter to refresh table
                break
            case "b":
                let buy = BuyFlow(configFile: configFile)
                buy.run()
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
        
        let displayRows = activeTransactions.map {
            ActiveDisplayRow(activeBuyTransaction: $0, priceSource: priceCache)
        }
        // Fill in averageReturnPercentage, which we can't calculate individually
        displayRows.forEach { row in
            let matchingTrxns = displayRows.filter { $0.ticker == row.ticker }
            let totalInvestment = matchingTrxns.reduce(into: 0, { $0 += $1.investment })
            let totalValue = matchingTrxns.reduce(into: 0, { $0 += $1.currentValue })
            row.averageReturnPercentage = (totalValue - totalInvestment) / totalInvestment
        }
        
        let currencyFormatter: NumberFormatter = {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            return fmt
        }()
        let fc /* format currency */ = { (n: Double) -> String in
            currencyFormatter.string(from: NSNumber(value: n)) ?? "$?.??"
        }
        let percentageFormatter: NumberFormatter = {
            let fmt = NumberFormatter()
            fmt.numberStyle = .percent
            fmt.minimumFractionDigits = 2
            fmt.maximumFractionDigits = 2
            return fmt
        }()
        let fp /* format percentage */ = { (p: Double) -> String in
            percentageFormatter.string(from: NSNumber(value: p)) ?? "?.??%"
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
            let avgReturnPercentage = row.averageReturnPercentage ?? 0
            let avgReturnColor = colorPercentage(avgReturnPercentage)
            return [
                TableCell(row.ticker, color: currentReturnColor),
                TableCell(row.companyName),
                TableCell(fc(row.investment)),
                TableCell(fc(row.currentPrice)),
                TableCell(fp(row.currentReturnPercentage), color: currentReturnColor),
                TableCell(fc(row.profit), color: currentProfitColor),
                TableCell(row.age.description),
                TableCell(fp(avgReturnPercentage), color: avgReturnColor)
            ]
        }
        let table = Table.renderTable(withHeaders: headers,
                                      rows: rows)
        print(table)
        print()
    }
    
    private func printMainMenu() {
        print("Main menu")
        print("    (b)uy")
        print("    (q)uit")
        print()
    }
}

private class ActiveDisplayRow {
    let ticker: String
    let companyName: String
    let investment: Double
    let currentPrice: Double
    let currentValue: Double // No need to display this one
    let currentReturnPercentage: Double
    let profit: Double
    let age: Int
    var averageReturnPercentage: Double?
    
    init(activeBuyTransaction trxn: ActiveBuyTransaction, priceSource: PriceCache) {
        let info = priceSource.info(forTicker: trxn.ticker)
        
        self.ticker = trxn.ticker
        self.companyName = info.companyName
        self.investment = trxn.investment
        self.currentPrice = info.price
        self.currentValue = currentPrice * trxn.shares
        self.currentReturnPercentage = (currentValue - investment) / investment
        self.profit = currentValue - investment
        self.age = Calendar.current.dateComponents([.day], from: trxn.buyDate, to: Date()).day ?? -1
        self.averageReturnPercentage = nil // Will be filled in later
    }
}
